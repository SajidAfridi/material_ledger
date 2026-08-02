import 'yorks_v1_project.dart';

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
    this.clientName,
  });

  final YorksV1Project project;
  final String? clientName;
  final int activeBuildingCount;
  final int activeProjectEngineerCount;
  final int activeSiteEngineerCount;

  int get activeTeamCount =>
      activeProjectEngineerCount + activeSiteEngineerCount;
}
