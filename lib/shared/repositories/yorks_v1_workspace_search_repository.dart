import 'dart:async';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_logistics.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_project_portfolio.dart';
import '../models/yorks_v1_role.dart';
import '../models/yorks_v1_workspace_search.dart';
import 'yorks_v1_boq_repository.dart';
import 'yorks_v1_documents_repository.dart';
import 'yorks_v1_logistics_repository.dart';
import 'yorks_v1_material_request_repository.dart';
import 'yorks_v1_project_portfolio_repository.dart';

/// Read-only search boundary for the workspace. Every source is an existing
/// role-safe repository projection; this class never queries Supabase itself.
class YorksV1WorkspaceSearchRepository {
  YorksV1WorkspaceSearchRepository({
    required YorksV1ProjectPortfolioRepository projects,
    required YorksV1MaterialRequestRepository materialRequests,
    required YorksV1BoqRepository boq,
    required YorksV1DocumentsRepository documents,
    required YorksV1LogisticsRepository logistics,
  }) : _projects = projects,
       _materialRequests = materialRequests,
       _boq = boq,
       _documents = documents,
       _logistics = logistics;

  final YorksV1ProjectPortfolioRepository _projects;
  final YorksV1MaterialRequestRepository _materialRequests;
  final YorksV1BoqRepository _boq;
  final YorksV1DocumentsRepository _documents;
  final YorksV1LogisticsRepository _logistics;

  Future<List<YorksV1WorkspaceSearchResult>>? _indexFuture;
  YorksV1Role? _indexedRole;

  Future<List<YorksV1WorkspaceSearchResult>> search(
    String query, {
    required YorksV1Role? role,
  }) async {
    final terms = _tokens(query);
    if (terms.isEmpty) return const [];
    final index = await _indexFor(role);
    final results = <YorksV1WorkspaceSearchResult>[];
    for (final result in index) {
      final haystack = result.searchableText.toLowerCase();
      if (!terms.every(haystack.contains)) continue;
      results.add(result.withScore(_score(result, terms)));
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score == 0 ? a.title.compareTo(b.title) : score;
    });
    return results.take(80).toList(growable: false);
  }

  void invalidate() {
    _indexFuture = null;
    _indexedRole = null;
  }

  Future<List<YorksV1WorkspaceSearchResult>> _indexFor(YorksV1Role? role) {
    if (_indexFuture != null && _indexedRole == role) return _indexFuture!;
    _indexedRole = role;
    return _indexFuture = _buildIndex(role);
  }

  Future<List<YorksV1WorkspaceSearchResult>> _buildIndex(
    YorksV1Role? role,
  ) async {
    final portfolio = await _safe(() => _projects.listPortfolio(), const []);
    final requests = await _safe(
      () => _materialRequests.listRequests(),
      const [],
    );
    final inventory =
        role == YorksV1Role.procurement || role == YorksV1Role.admin
        ? await _safe(() => _logistics.getInventory(), null)
        : null;

    final results = <YorksV1WorkspaceSearchResult>[
      for (final item in portfolio) _projectResult(item),
      for (final request in requests) ...[
        _requestResult(request),
        for (final line in request.lines)
          _materialRequestLineResult(request, line),
      ],
      if (inventory != null)
        for (final item in inventory.items) _inventoryResult(item),
    ];

    final projectData = await Future.wait([
      for (final item in portfolio)
        _projectSearchData(item).catchError((_) => const _ProjectSearchData()),
    ]);
    for (final data in projectData) {
      results
        ..addAll(data.groups)
        ..addAll(data.items)
        ..addAll(data.documents);
    }
    return results;
  }

  Future<_ProjectSearchData> _projectSearchData(
    YorksV1ProjectPortfolioItem item,
  ) async {
    final groups = await _safe(
      () => _boq.listGroups(item.project.id),
      const [],
    );
    final groupResults = <YorksV1WorkspaceSearchResult>[];
    final itemResults = <YorksV1WorkspaceSearchResult>[];
    for (final group in groups) {
      groupResults.add(_groupResult(item, group));
      if (group.rowCount == 0) continue;
      final worksheet = await _safe(() => _boq.getWorksheet(group.id), null);
      if (worksheet == null) continue;
      for (final row in worksheet.rows) {
        final values = _operationalRowValues(worksheet, row);
        final description = _firstNonBlank([
          values['description'],
          values['item description'],
          values['name'],
        ]);
        final title = description ?? row.id;
        itemResults.add(
          YorksV1WorkspaceSearchResult(
            kind: YorksV1WorkspaceSearchResultKind.boqItem,
            title: title,
            subtitle:
                '${group.effectiveTitle} · ${item.project.reference} · Row ${row.displayOrder}',
            route: _boqPath(item.project.id, group.id),
            projectId: item.project.id,
            entityId: row.id,
            searchableText: [
              title,
              group.effectiveTitle,
              'boq item',
              item.project.reference,
              item.project.name,
              ...values.values,
            ].join(' '),
          ),
        );
      }
    }

    final documents = await _safe(
      () => _documents.getWorkspace(item.project.id),
      null,
    );
    final documentResults = <YorksV1WorkspaceSearchResult>[];
    if (documents != null) {
      for (final document in documents.documents) {
        final link = document.links
            .where((value) => value.projectId == item.project.id)
            .firstOrNull;
        final focus = link == null
            ? ''
            : '&entity_type=${Uri.encodeQueryComponent(link.entityType.wireValue)}'
                  '&entity_id=${Uri.encodeQueryComponent(link.entityId)}';
        documentResults.add(
          YorksV1WorkspaceSearchResult(
            kind: YorksV1WorkspaceSearchResultKind.document,
            title: document.currentVersion.fileName,
            subtitle:
                '${item.project.reference} · ${document.classification.name}',
            route:
                '/yorks/projects/${item.project.id}/documents?focus=search$focus',
            projectId: item.project.id,
            entityId: document.id,
            searchableText: [
              document.currentVersion.fileName,
              document.currentVersion.mimeType,
              document.classification.name,
              'document documents',
              item.project.reference,
              item.project.name,
            ].join(' '),
          ),
        );
      }
    }
    return _ProjectSearchData(
      groups: groupResults,
      items: itemResults,
      documents: documentResults,
    );
  }

  YorksV1WorkspaceSearchResult _projectResult(
    YorksV1ProjectPortfolioItem item,
  ) {
    final project = item.project;
    return YorksV1WorkspaceSearchResult(
      kind: YorksV1WorkspaceSearchResultKind.project,
      title: project.name,
      subtitle: '${project.reference} · ${project.state.name}',
      route: '/yorks/projects/${project.id}',
      projectId: project.id,
      entityId: project.id,
      searchableText: [
        project.name,
        project.reference,
        project.clientName,
        project.jobOrContractReference,
        project.siteLocation,
        project.city,
        project.notes,
      ].whereType<String>().join(' '),
    );
  }

  YorksV1WorkspaceSearchResult _groupResult(
    YorksV1ProjectPortfolioItem item,
    YorksV1BoqGroup group,
  ) => YorksV1WorkspaceSearchResult(
    kind: YorksV1WorkspaceSearchResultKind.boqGroup,
    title: group.effectiveTitle,
    subtitle: '${item.project.reference} · ${group.rowCount} items',
    route: _boqPath(item.project.id, group.id),
    projectId: item.project.id,
    entityId: group.id,
    searchableText: [
      group.name,
      group.worksheetTitle,
      'boq group',
      item.project.reference,
      item.project.name,
    ].join(' '),
  );

  YorksV1WorkspaceSearchResult _requestResult(
    YorksV1MaterialRequest request,
  ) => YorksV1WorkspaceSearchResult(
    kind: YorksV1WorkspaceSearchResultKind.materialRequest,
    title: request.requestNumber ?? request.title ?? request.id,
    subtitle:
        '${request.projectReference} · ${request.scopeName} · ${request.state.name}',
    route: '/yorks/material-requests/${request.id}',
    projectId: request.projectId,
    entityId: request.id,
    searchableText: [
      request.requestNumber,
      request.title,
      request.projectReference,
      request.projectName,
      request.scopeName,
      request.state.name,
      request.requesterDisplayName,
      request.deliveryNote,
      'material request',
      for (final line in request.lines) ...[
        line.description,
        line.brandOrigin,
        line.unit,
      ],
    ].whereType<String>().join(' '),
  );

  YorksV1WorkspaceSearchResult _materialRequestLineResult(
    YorksV1MaterialRequest request,
    YorksV1MaterialRequestLine line,
  ) {
    final title = line.description.trim().isEmpty
        ? line.id
        : line.description.trim();
    return YorksV1WorkspaceSearchResult(
      kind: YorksV1WorkspaceSearchResultKind.materialItem,
      title: title,
      subtitle:
          '${request.requestNumber ?? request.id} · ${line.quantity} ${line.unit}',
      route: '/yorks/material-requests/${request.id}',
      projectId: request.projectId,
      entityId: line.id,
      searchableText: [
        title,
        line.brandOrigin,
        line.unit,
        'material item',
        request.requestNumber,
        request.title,
        request.projectReference,
        request.projectName,
        request.scopeName,
      ].whereType<String>().join(' '),
    );
  }

  YorksV1WorkspaceSearchResult _inventoryResult(
    YorksV1LogisticsInventoryItem item,
  ) => YorksV1WorkspaceSearchResult(
    kind: YorksV1WorkspaceSearchResultKind.materialItem,
    title: item.description,
    subtitle: [item.brandOrigin, item.unit].whereType<String>().join(' · '),
    route: '/yorks/inventory',
    entityId: item.id,
    searchableText: [
      item.description,
      item.brandOrigin,
      item.unit,
      'material item inventory',
    ].whereType<String>().join(' '),
  );

  Map<String, String> _operationalRowValues(
    YorksV1BoqWorksheet worksheet,
    YorksV1BoqRow row,
  ) {
    final values = <String, String>{};
    for (final column in worksheet.columns.where(
      (item) => !item.isCommercial,
    )) {
      final value = row.valueFor(column.id)?.toString().trim();
      if (value == null || value.isEmpty) continue;
      values[column.heading.trim().toLowerCase()] = value;
    }
    for (final field in YorksV1BoqCanonicalField.values) {
      final value = row.canonicalValues[field.wireValue]?.toString().trim();
      if (value == null || value.isEmpty) continue;
      values[field.wireValue] = value;
    }
    return values;
  }

  int _score(YorksV1WorkspaceSearchResult result, List<String> terms) {
    final title = result.title.toLowerCase();
    var score = 0;
    for (final term in terms) {
      if (title == term) {
        score += 1000;
      } else if (title.startsWith(term)) {
        score += 700;
      } else if (title.contains(term)) {
        score += 450;
      } else {
        score += 100;
      }
    }
    score += switch (result.kind) {
      YorksV1WorkspaceSearchResultKind.project => 80,
      YorksV1WorkspaceSearchResultKind.materialRequest => 70,
      YorksV1WorkspaceSearchResultKind.document => 60,
      YorksV1WorkspaceSearchResultKind.boqGroup => 50,
      YorksV1WorkspaceSearchResultKind.boqItem => 40,
      YorksV1WorkspaceSearchResultKind.materialItem => 30,
      YorksV1WorkspaceSearchResultKind.module => 20,
    };
    return score;
  }

  List<String> _tokens(String query) => query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  String? _firstNonBlank(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _boqPath(String projectId, String groupId) =>
      '/yorks/projects/$projectId/boq/$groupId';

  Future<T> _safe<T>(Future<T> Function() task, T fallback) async {
    try {
      return await task();
    } catch (_) {
      return fallback;
    }
  }
}

class _ProjectSearchData {
  const _ProjectSearchData({
    this.groups = const [],
    this.items = const [],
    this.documents = const [],
  });

  final List<YorksV1WorkspaceSearchResult> groups;
  final List<YorksV1WorkspaceSearchResult> items;
  final List<YorksV1WorkspaceSearchResult> documents;
}
