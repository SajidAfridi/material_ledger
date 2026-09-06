import 'dart:async';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_document.dart';
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
    Duration cacheTtl = const Duration(minutes: 2),
  }) : _projects = projects,
       _materialRequests = materialRequests,
       _boq = boq,
       _documents = documents,
       _logistics = logistics,
       _cacheTtl = cacheTtl;

  final YorksV1ProjectPortfolioRepository _projects;
  final YorksV1MaterialRequestRepository _materialRequests;
  final YorksV1BoqRepository _boq;
  final YorksV1DocumentsRepository _documents;
  final YorksV1LogisticsRepository _logistics;
  final Duration _cacheTtl;

  Future<_SearchIndexSnapshot>? _indexFuture;
  YorksV1Role? _indexedRole;
  DateTime? _indexStartedAt;

  Future<YorksV1WorkspaceSearchResponse> search(
    String query, {
    required YorksV1Role? role,
  }) async {
    final terms = _tokens(query);
    if (terms.isEmpty) {
      return const YorksV1WorkspaceSearchResponse(results: []);
    }
    final snapshot = await _indexFor(role);
    final results = <YorksV1WorkspaceSearchResult>[];
    for (final result in snapshot.results) {
      final haystack = normalizeYorksWorkspaceSearchText(result.searchableText);
      if (!terms.every(
        (term) => yorksWorkspaceSearchTermMatches(haystack, term),
      )) {
        continue;
      }
      results.add(result.withScore(_score(result, terms)));
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score == 0 ? a.title.compareTo(b.title) : score;
    });
    return YorksV1WorkspaceSearchResponse(
      results: results.take(60).toList(growable: false),
      isPartial: snapshot.isPartial,
    );
  }

  void invalidate() {
    _indexFuture = null;
    _indexedRole = null;
    _indexStartedAt = null;
  }

  Future<_SearchIndexSnapshot> _indexFor(YorksV1Role? role) {
    final startedAt = _indexStartedAt;
    final fresh =
        startedAt != null && DateTime.now().difference(startedAt) < _cacheTtl;
    if (_indexFuture != null && _indexedRole == role && fresh) {
      return _indexFuture!;
    }
    _indexedRole = role;
    _indexStartedAt = DateTime.now();
    return _indexFuture = _buildIndex(role);
  }

  Future<_SearchIndexSnapshot> _buildIndex(YorksV1Role? role) async {
    final portfolioFuture = _capture(
      () => _projects.listPortfolio(),
      const <YorksV1ProjectPortfolioItem>[],
    );
    final requestsFuture = _capture(
      () => _materialRequests.listRequests(),
      const <YorksV1MaterialRequest>[],
    );
    final portfolioLoad = await portfolioFuture;
    final requestLoad = await requestsFuture;
    final portfolio = portfolioLoad.value;
    final requests = requestLoad.value;
    var partial = portfolioLoad.failed || requestLoad.failed;
    YorksV1InventoryWorkspace? inventory;
    if (role == YorksV1Role.procurement || role == YorksV1Role.admin) {
      final inventoryLoad = await _capture<YorksV1InventoryWorkspace?>(
        () => _logistics.getInventory(),
        null,
      );
      inventory = inventoryLoad.value;
      partial = partial || inventoryLoad.failed;
    }

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
        _projectSearchData(
          item,
        ).catchError((_) => const _ProjectSearchData(isPartial: true)),
    ]);
    for (final data in projectData) {
      partial = partial || data.isPartial;
      results
        ..addAll(data.groups)
        ..addAll(data.items)
        ..addAll(data.documents);
    }
    return _SearchIndexSnapshot(results: results, isPartial: partial);
  }

  Future<_ProjectSearchData> _projectSearchData(
    YorksV1ProjectPortfolioItem item,
  ) async {
    final groupsLoad = await _capture(
      () => _boq.listGroupsForScope(item.project.id),
      const <YorksV1BoqGroup>[],
    );
    final groups = groupsLoad.value;
    var partial = groupsLoad.failed;
    final groupResults = <YorksV1WorkspaceSearchResult>[];
    final itemResults = <YorksV1WorkspaceSearchResult>[];
    for (final group in groups) {
      groupResults.add(_groupResult(item, group));
      if (group.rowCount == 0) continue;
      final worksheetLoad = await _capture<YorksV1BoqWorksheet?>(
        () => _boq.getWorksheet(group.id),
        null,
      );
      partial = partial || worksheetLoad.failed;
      final worksheet = worksheetLoad.value;
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
                '${_scopeLabel(group)} · ${group.effectiveTitle} · ${item.project.reference} · Row ${row.displayOrder}',
            route: _boqPath(item.project.id, group.id),
            projectId: item.project.id,
            entityId: row.id,
            searchableText: [
              title,
              group.effectiveTitle,
              'boq bill quantity item row',
              item.project.reference,
              item.project.name,
              ...values.values,
            ].join(' '),
          ),
        );
      }
    }

    final documentsLoad = await _capture<YorksV1DocumentWorkspace?>(
      () => _documents.getWorkspace(item.project.id),
      null,
    );
    partial = partial || documentsLoad.failed;
    final documents = documentsLoad.value;
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
      isPartial: partial,
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
        'project job contract site',
      ].whereType<String>().join(' '),
    );
  }

  YorksV1WorkspaceSearchResult _groupResult(
    YorksV1ProjectPortfolioItem item,
    YorksV1BoqGroup group,
  ) => YorksV1WorkspaceSearchResult(
    kind: YorksV1WorkspaceSearchResultKind.boqGroup,
    title: group.effectiveTitle,
    subtitle:
        '${_scopeLabel(group)} · ${item.project.reference} · ${group.rowCount} items',
    route: _boqPath(item.project.id, group.id),
    projectId: item.project.id,
    entityId: group.id,
    searchableText: [
      group.name,
      group.worksheetTitle,
      group.scopeName,
      group.scopeCode,
      'boq bill quantity group folder',
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
      'material request mr requisition',
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
        'material item mr request',
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
      'material item inventory stock warehouse',
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
    final title = normalizeYorksWorkspaceSearchText(result.title);
    final phrase = terms.join(' ');
    var score = 0;
    if (title == phrase) {
      score += 1400;
    } else if (title.startsWith(phrase)) {
      score += 900;
    }
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

  List<String> _tokens(String query) => normalizeYorksWorkspaceSearchText(query)
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

  String _scopeLabel(YorksV1BoqGroup group) =>
      group.scopeName ?? group.scopeCode ?? group.effectiveTitle;

  Future<_Captured<T>> _capture<T>(
    Future<T> Function() task,
    T fallback,
  ) async {
    try {
      return _Captured(value: await task());
    } catch (_) {
      return _Captured(value: fallback, failed: true);
    }
  }
}

class _ProjectSearchData {
  const _ProjectSearchData({
    this.groups = const [],
    this.items = const [],
    this.documents = const [],
    this.isPartial = false,
  });

  final List<YorksV1WorkspaceSearchResult> groups;
  final List<YorksV1WorkspaceSearchResult> items;
  final List<YorksV1WorkspaceSearchResult> documents;
  final bool isPartial;
}

class _SearchIndexSnapshot {
  const _SearchIndexSnapshot({required this.results, required this.isPartial});

  final List<YorksV1WorkspaceSearchResult> results;
  final bool isPartial;
}

class _Captured<T> {
  const _Captured({required this.value, this.failed = false});

  final T value;
  final bool failed;
}
