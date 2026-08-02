/// Compile-time rollout controls for the Yorks V1 R35 experience.
///
/// Constructor values represent requested deployment settings. Public getters
/// expose only effective settings: every downstream feature also requires all
/// preceding features in the approved dependency chain. This keeps a partial
/// or inconsistent deployment fail-closed.
///
/// These flags are intentionally separate from `NexusFeatureFlags`. Legacy V7
/// deployment settings do not enable Yorks V1 behavior.
class YorksV1FeatureFlags {
  const YorksV1FeatureFlags({
    bool foundation = false,
    bool projects = false,
    bool boq = false,
    bool excel = false,
    bool requests = false,
    bool arrangement = false,
    bool logistics = false,
    bool returnsDocuments = false,
    bool documents = false,
  }) : _foundation = foundation,
       _projects = projects,
       _boq = boq,
       _excel = excel,
       _requests = requests,
       _arrangement = arrangement,
       _logistics = logistics,
       _returnsDocuments = returnsDocuments,
       _documents = documents;

  const YorksV1FeatureFlags.fromEnvironment()
    : _foundation = const bool.fromEnvironment('YORKS_V1_FOUNDATION'),
      _projects = const bool.fromEnvironment('YORKS_V1_PROJECTS'),
      _boq = const bool.fromEnvironment('YORKS_V1_BOQ'),
      _excel = const bool.fromEnvironment('YORKS_V1_EXCEL'),
      _requests = const bool.fromEnvironment('YORKS_V1_REQUESTS'),
      _arrangement = const bool.fromEnvironment('YORKS_V1_ARRANGEMENT'),
      _logistics = const bool.fromEnvironment('YORKS_V1_LOGISTICS'),
      _returnsDocuments = const bool.fromEnvironment(
        'YORKS_V1_RETURNS_DOCUMENTS',
      ),
      _documents = const bool.fromEnvironment('YORKS_V1_DOCUMENTS');

  final bool _foundation;
  final bool _projects;
  final bool _boq;
  final bool _excel;
  final bool _requests;
  final bool _arrangement;
  final bool _logistics;
  final bool _returnsDocuments;
  final bool _documents;

  bool get foundation => _foundation;
  bool get projects => foundation && _projects;
  bool get boq => projects && _boq;
  bool get excel => boq && _excel;
  bool get requests => excel && _requests;
  bool get arrangement => requests && _arrangement;
  bool get logistics => arrangement && _logistics;
  bool get returnsDocuments => logistics && _returnsDocuments;
  bool get documents => returnsDocuments && _documents;
}
