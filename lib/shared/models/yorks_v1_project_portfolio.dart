import 'yorks_v1_project.dart';
import 'yorks_v1_domain_error.dart';

/// A compact, non-commercial project card/row projection.
///
/// This deliberately keeps the portfolio separate from the legacy project
/// register.  Every value is sourced from a normalized V1 relation protected
/// by its existing RLS policy; no commercial relation or legacy JSON snapshot
/// participates in this read model.
class YorksV1ProjectPortfolioItem {
  const YorksV1ProjectPortfolioItem({
    required this.project,
    required this.activeBuildingCount,
    required this.activeProjectEngineerCount,
    required this.activeSiteEngineerCount,
    this.activeMembers = const [],
    this.parties = const [],
    this.buildings = const [],
    this.clientName,
  });

  final YorksV1Project project;
  final String? clientName;
  final int activeBuildingCount;
  final int activeProjectEngineerCount;
  final int activeSiteEngineerCount;
  final List<YorksV1ProjectMember> activeMembers;
  final List<YorksV1ProjectPartyInput> parties;
  final List<YorksV1ProjectBuildingInput> buildings;

  int get activeTeamCount =>
      activeProjectEngineerCount + activeSiteEngineerCount;
}

/// Exact project lifecycle totals plus a bounded first-screen project list.
///
/// The complete portfolio remains available in the Projects workspace. This
/// projection exists so the application Overview does not hydrate every
/// party, scope and team membership before it can become useful.
class YorksV1ProjectOverview {
  YorksV1ProjectOverview({
    required List<YorksV1ProjectPortfolioItem> items,
    required this.total,
    required this.active,
    required this.onHold,
    required this.completed,
  }) : items = List.unmodifiable(items);

  final List<YorksV1ProjectPortfolioItem> items;
  final int total;
  final int active;
  final int onHold;
  final int completed;

  factory YorksV1ProjectOverview.fromItems(
    List<YorksV1ProjectPortfolioItem> items,
  ) => YorksV1ProjectOverview(
    items: items.take(6).toList(growable: false),
    total: items.length,
    active: items
        .where((item) => item.project.state == YorksV1ProjectLifecycle.active)
        .length,
    onHold: items
        .where((item) => item.project.state == YorksV1ProjectLifecycle.onHold)
        .length,
    completed: items
        .where(
          (item) => item.project.state == YorksV1ProjectLifecycle.completed,
        )
        .length,
  );

  factory YorksV1ProjectOverview.fromRpcJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final counts = json['counts'];
    if (rawItems is! List || counts is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final values = Map<String, dynamic>.from(counts);
    final items = <YorksV1ProjectPortfolioItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      items.add(
        YorksV1ProjectPortfolioItem(
          project: YorksV1Project.fromRpcJson(row),
          clientName: _optionalString(row['client_name']),
          activeBuildingCount: _overviewCount(row['active_building_count']),
          activeProjectEngineerCount: _overviewCount(
            row['active_project_engineer_count'],
          ),
          activeSiteEngineerCount: _overviewCount(
            row['active_site_engineer_count'],
          ),
        ),
      );
    }
    return YorksV1ProjectOverview(
      items: items,
      total: _overviewCount(values['total']),
      active: _overviewCount(values['active']),
      onHold: _overviewCount(values['on_hold']),
      completed: _overviewCount(values['completed']),
    );
  }
}

int _overviewCount(Object? value) {
  final count = switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
  if (count == null || count < 0) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return count;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
