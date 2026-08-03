import 'yorks_v1_material_request.dart';

/// Server-aggregated, role-safe source for every rendering of a controlled
/// Material Request.  The app never reconstructs approval, dispatch or
/// receipt facts from local state, so preview, download, print and stored PDF
/// use the same immutable view of the request.
class YorksV1MaterialRequestDocumentModel {
  const YorksV1MaterialRequestDocumentModel({
    required this.request,
    this.projectEngineerNames = const [],
    this.approval,
    this.dispatch,
    this.receiptStatuses = const {},
  });

  final YorksV1MaterialRequest request;
  final List<String> projectEngineerNames;
  final YorksV1MaterialRequestDocumentActor? approval;
  final YorksV1MaterialRequestDocumentActor? dispatch;
  final Map<String, String> receiptStatuses;

  factory YorksV1MaterialRequestDocumentModel.fromRequest(
    YorksV1MaterialRequest request,
  ) => YorksV1MaterialRequestDocumentModel(request: request);

  factory YorksV1MaterialRequestDocumentModel.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final engineerNames = (json['project_engineers'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _text(value['display_name']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final statusEntries = <String, String>{};
    for (final value in json['receipt_statuses'] as List? ?? const []) {
      if (value is! Map) continue;
      final lineId = _text(value['request_line_id']);
      final status = _text(value['status']);
      if (lineId.isNotEmpty && status.isNotEmpty) {
        statusEntries[lineId] = status;
      }
    }
    return YorksV1MaterialRequestDocumentModel(
      request: YorksV1MaterialRequest.fromRpcJson(
        Map<String, dynamic>.from(json['request'] as Map),
      ),
      projectEngineerNames: engineerNames,
      approval: YorksV1MaterialRequestDocumentActor.fromNullableJson(
        json['approval'],
      ),
      dispatch: YorksV1MaterialRequestDocumentActor.fromNullableJson(
        json['dispatch'],
      ),
      receiptStatuses: Map.unmodifiable(statusEntries),
    );
  }
}

class YorksV1MaterialRequestDocumentActor {
  const YorksV1MaterialRequestDocumentActor({
    required this.displayName,
    required this.role,
    required this.reference,
    required this.actedAt,
  });

  final String displayName;
  final String role;
  final String reference;
  final DateTime? actedAt;

  static YorksV1MaterialRequestDocumentActor? fromNullableJson(Object? value) {
    if (value is! Map) return null;
    final displayName = _text(value['display_name']);
    if (displayName.isEmpty) return null;
    return YorksV1MaterialRequestDocumentActor(
      displayName: displayName,
      role: _text(value['role']),
      reference: _text(value['reference']),
      actedAt: DateTime.tryParse(_text(value['acted_at']))?.toUtc(),
    );
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';
