/// Incremental rollout controls for the transformed Nexus V7 modules.
///
/// Every flag defaults off so an incomplete batch can be merged without
/// exposing unfinished workflows. Flags are compile-time deployment settings.
class NexusFeatureFlags {
  const NexusFeatureFlags({
    this.projects = false,
    this.browseMaterials = false,
    this.phase1Planning = false,
    this.procurementReview = false,
    this.phase2Requests = false,
  });

  const NexusFeatureFlags.fromEnvironment()
    : projects = const bool.fromEnvironment('NEXUS_V7_PROJECTS'),
      browseMaterials = const bool.fromEnvironment('NEXUS_V7_BROWSE_MATERIALS'),
      phase1Planning = const bool.fromEnvironment('NEXUS_V7_PHASE1_PLANNING'),
      procurementReview = const bool.fromEnvironment(
        'NEXUS_V7_PROCUREMENT_REVIEW',
      ),
      phase2Requests = const bool.fromEnvironment('NEXUS_V7_PHASE2_REQUESTS');

  final bool projects;
  final bool browseMaterials;
  final bool phase1Planning;
  final bool procurementReview;
  final bool phase2Requests;

  NexusFeatureFlags copyWith({
    bool? projects,
    bool? browseMaterials,
    bool? phase1Planning,
    bool? procurementReview,
    bool? phase2Requests,
  }) {
    return NexusFeatureFlags(
      projects: projects ?? this.projects,
      browseMaterials: browseMaterials ?? this.browseMaterials,
      phase1Planning: phase1Planning ?? this.phase1Planning,
      procurementReview: procurementReview ?? this.procurementReview,
      phase2Requests: phase2Requests ?? this.phase2Requests,
    );
  }
}
