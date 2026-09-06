import 'package:flutter/material.dart';

enum YorksV1WorkspaceSearchResultKind {
  module,
  project,
  boqGroup,
  boqItem,
  materialRequest,
  materialItem,
  document,
}

class YorksV1WorkspaceSearchResponse {
  const YorksV1WorkspaceSearchResponse({
    required this.results,
    this.isPartial = false,
  });

  final List<YorksV1WorkspaceSearchResult> results;
  final bool isPartial;
}

/// Normalizes punctuation, spacing and common Arabic/Latin variants without
/// translating or expanding the role-safe text returned by repositories.
String normalizeYorksWorkspaceSearchText(String value) {
  var normalized = value.toLowerCase();
  const replacements = <String, String>{
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ؤ': 'و',
    'ئ': 'ي',
    'ة': 'ه',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(
        RegExp(r'[^a-z0-9\u0600-\u06ff\u0750-\u077f\u0900-\u097f]+'),
        ' ',
      )
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool yorksWorkspaceSearchTermMatches(String normalizedHaystack, String term) {
  if (normalizedHaystack.contains(term)) return true;
  if (normalizedHaystack.replaceAll(' ', '').contains(term)) return true;
  if (term.length < 4) return false;
  return normalizedHaystack
      .split(' ')
      .any(
        (token) =>
            token.length >= 4 &&
            _workspaceSearchEditDistanceAtMostOne(token, term),
      );
}

bool _workspaceSearchEditDistanceAtMostOne(String left, String right) {
  if ((left.length - right.length).abs() > 1) return false;
  var leftIndex = 0;
  var rightIndex = 0;
  var edits = 0;
  while (leftIndex < left.length && rightIndex < right.length) {
    if (left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex)) {
      leftIndex++;
      rightIndex++;
      continue;
    }
    if (++edits > 1) return false;
    if (left.length > right.length) {
      leftIndex++;
    } else if (right.length > left.length) {
      rightIndex++;
    } else {
      leftIndex++;
      rightIndex++;
    }
  }
  if (leftIndex < left.length || rightIndex < right.length) edits++;
  return edits <= 1;
}

/// A safe, navigable search hit. The searchable text is built only from the
/// role-safe projections returned by the Yorks V1 repositories.
class YorksV1WorkspaceSearchResult {
  const YorksV1WorkspaceSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.searchableText,
    this.projectId,
    this.entityId,
    this.score = 0,
  });

  final YorksV1WorkspaceSearchResultKind kind;
  final String title;
  final String subtitle;
  final String route;
  final String searchableText;
  final String? projectId;
  final String? entityId;
  final int score;

  YorksV1WorkspaceSearchResult withScore(int value) =>
      YorksV1WorkspaceSearchResult(
        kind: kind,
        title: title,
        subtitle: subtitle,
        route: route,
        searchableText: searchableText,
        projectId: projectId,
        entityId: entityId,
        score: value,
      );

  IconData get icon => switch (kind) {
    YorksV1WorkspaceSearchResultKind.module => Icons.grid_view_rounded,
    YorksV1WorkspaceSearchResultKind.project => Icons.account_tree_rounded,
    YorksV1WorkspaceSearchResultKind.boqGroup => Icons.folder_outlined,
    YorksV1WorkspaceSearchResultKind.boqItem => Icons.table_rows_outlined,
    YorksV1WorkspaceSearchResultKind.materialRequest =>
      Icons.assignment_rounded,
    YorksV1WorkspaceSearchResultKind.materialItem => Icons.inventory_2_rounded,
    YorksV1WorkspaceSearchResultKind.document => Icons.description_outlined,
  };
}
