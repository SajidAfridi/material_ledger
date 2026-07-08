import 'dart:convert';

import 'project.dart';

/// Status of a material request.
enum RequestStatus {
  draft('Draft', 'مسودہ', 'مسودة', 'ड्राफ्ट'),
  pending('Pending', 'زیر التواء', 'معلق', 'लंबित'),
  sourcing('Sourcing', 'بندوبست', 'توريد', 'सोर्सिंग'),
  partial('Partial', 'جزوی', 'جزئي', 'आंशिक'),
  dispatched('Dispatched', 'روانہ', 'تم الإرسال', 'भेजा गया'),
  received('Received', 'موصول', 'تم الاستلام', 'प्राप्त'),
  onHold('On Hold', 'روکا ہوا', 'موقوف', 'रोका गया'),
  cancelled('Cancelled', 'منسوخ', 'ملغى', 'रद्द');

  const RequestStatus(
    this.label,
    this.urduLabel,
    this.arabicLabel,
    this.hindiLabel,
  );

  final String label;
  final String urduLabel;
  final String arabicLabel;
  final String hindiLabel;

  static RequestStatus fromLabel(String label) {
    return RequestStatus.values.firstWhere(
      (s) => s.label == label,
      orElse: () => RequestStatus.pending,
    );
  }
}

/// Priority level for a material request.
enum RequestPriority {
  normal('Normal', 'عام', 'عادي', 'सामान्य'),
  urgent('Urgent', 'فوری', 'عاجل', 'अत्यावश्यक');

  const RequestPriority(
    this.label,
    this.urduLabel,
    this.arabicLabel,
    this.hindiLabel,
  );

  final String label;
  final String urduLabel;
  final String arabicLabel;
  final String hindiLabel;

  static RequestPriority fromLabel(String label) {
    return RequestPriority.values.firstWhere(
      (p) => p.label == label,
      orElse: () => RequestPriority.normal,
    );
  }
}

/// A single comment in a request's engineer ↔ procurement discussion thread.
class RequestComment {
  const RequestComment({
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

  factory RequestComment.fromJson(Map<String, dynamic> json) => RequestComment(
    authorName: json['authorName'] as String? ?? '',
    authorRole: json['authorRole'] as String? ?? '',
    text: json['text'] as String? ?? '',
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// A single material request from an engineer to the warehouse.
class MaterialRequest {
  const MaterialRequest({
    required this.id,
    required this.projectName,
    required this.projectNameSecondary,
    required this.status,
    required this.requestDate,
    required this.itemCount,
    this.projectId,
    this.lineItems = const [],
    this.priority = RequestPriority.normal,
    this.siteLocation,
    this.notes,
    this.engineerId,
    this.confirmedReceiptAt,
    this.comments = const [],
    // Soft-delete: the sync outbox only ever upserts, never issues a real SQL
    // DELETE — a physical local removal would resurrect on the next cloud
    // hydration. Deleting flips this instead (mirrors Project.deleted).
    this.deleted = false,
  });

  final String id;

  /// Stable id of the [Project] this request belongs to. Null on legacy requests
  /// created before this field existed (match by [projectName] as a fallback).
  /// Keying off the id — not the name — stops two same-named jobs sharing state.
  final String? projectId;

  final String projectName;
  final String projectNameSecondary;
  final RequestStatus status;
  final DateTime requestDate;
  final int itemCount;
  final List<RequestLineItem> lineItems;
  final RequestPriority priority;
  final String? siteLocation;
  final String? notes;
  final String? engineerId;

  /// When the engineer confirmed on-site receipt (FR-088). Null until then.
  final DateTime? confirmedReceiptAt;

  /// Engineer ↔ procurement discussion thread (e.g. resolving short stock).
  final List<RequestComment> comments;

  /// Soft-delete tombstone — see the constructor comment on [deleted].
  final bool deleted;

  /// Distinct categories represented in line items.
  int get categoryCount {
    return lineItems.map((e) => e.unitSymbol).toSet().length.clamp(1, 10);
  }

  MaterialRequest copyWith({
    String? projectId,
    String? projectName,
    String? projectNameSecondary,
    RequestStatus? status,
    DateTime? requestDate,
    int? itemCount,
    List<RequestLineItem>? lineItems,
    RequestPriority? priority,
    String? siteLocation,
    String? notes,
    String? engineerId,
    DateTime? confirmedReceiptAt,
    List<RequestComment>? comments,
    bool? deleted,
  }) {
    return MaterialRequest(
      id: id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      projectNameSecondary: projectNameSecondary ?? this.projectNameSecondary,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      itemCount: itemCount ?? this.itemCount,
      lineItems: lineItems ?? this.lineItems,
      priority: priority ?? this.priority,
      siteLocation: siteLocation ?? this.siteLocation,
      notes: notes ?? this.notes,
      engineerId: engineerId ?? this.engineerId,
      confirmedReceiptAt: confirmedReceiptAt ?? this.confirmedReceiptAt,
      comments: comments ?? this.comments,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'projectName': projectName,
    'projectNameSecondary': projectNameSecondary,
    'status': status.label,
    'requestDate': requestDate.toIso8601String(),
    'itemCount': itemCount,
    'lineItems': lineItems.map((e) => e.toJson()).toList(),
    'priority': priority.label,
    'siteLocation': siteLocation,
    'notes': notes,
    'engineerId': engineerId,
    'confirmedReceiptAt': confirmedReceiptAt?.toIso8601String(),
    'comments': comments.map((e) => e.toJson()).toList(),
    'deleted': deleted,
  };

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    final lineItemsList = json['lineItems'] as List<dynamic>?;
    return MaterialRequest(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String? ?? '',
      projectNameSecondary: json['projectNameSecondary'] as String? ?? '',
      status: RequestStatus.fromLabel(json['status'] as String? ?? ''),
      requestDate:
          DateTime.tryParse(json['requestDate'] as String? ?? '') ??
          DateTime.now(),
      // JSON has no int/double distinction — a synced `3.0` decodes as double, so
      // `as num?` then toInt() (never `as int`, which would throw).
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      lineItems:
          lineItemsList
              ?.map((e) => RequestLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      priority: RequestPriority.fromLabel(
        json['priority'] as String? ?? 'Normal',
      ),
      siteLocation: json['siteLocation'] as String?,
      notes: json['notes'] as String?,
      engineerId: json['engineerId'] as String?,
      confirmedReceiptAt: json['confirmedReceiptAt'] == null
          ? null
          : DateTime.parse(json['confirmedReceiptAt'] as String),
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => RequestComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  /// Encode a list for SharedPreferences storage.
  static String encodeList(List<MaterialRequest> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  /// Decode a list from SharedPreferences storage.
  static List<MaterialRequest> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => MaterialRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
