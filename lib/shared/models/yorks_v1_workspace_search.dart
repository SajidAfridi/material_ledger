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
