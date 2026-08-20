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
    bool legacyArrangementReview = false,
    bool logistics = false,
    bool returnsDocuments = false,
    bool documents = false,
    bool teamChat = false,
    bool inventorySuppliers = false,
  }) : _foundation = foundation,
       _projects = projects,
       _boq = boq,
       _excel = excel,
       _requests = requests,
       _arrangement = arrangement,
       _legacyArrangementReview = legacyArrangementReview,
       _logistics = logistics,
       _returnsDocuments = returnsDocuments,
       _documents = documents,
       _teamChat = teamChat,
       _inventorySuppliers = inventorySuppliers;

  const YorksV1FeatureFlags.fromEnvironment()
    : _foundation = const bool.fromEnvironment(
        'YORKS_V1_FOUNDATION',
        defaultValue: true,
      ),
      _projects = const bool.fromEnvironment(
        'YORKS_V1_PROJECTS',
        defaultValue: true,
      ),
      _boq = const bool.fromEnvironment('YORKS_V1_BOQ', defaultValue: true),
      _excel = const bool.fromEnvironment('YORKS_V1_EXCEL', defaultValue: true),
      _requests = const bool.fromEnvironment(
        'YORKS_V1_REQUESTS',
        defaultValue: true,
      ),
      _arrangement = const bool.fromEnvironment(
        'YORKS_V1_ARRANGEMENT',
        defaultValue: true,
      ),
      _legacyArrangementReview = const bool.fromEnvironment(
        'YORKS_V1_LEGACY_ARRANGEMENT_REVIEW',
        defaultValue: false,
      ),
      _logistics = const bool.fromEnvironment(
        'YORKS_V1_LOGISTICS',
        defaultValue: true,
      ),
      _returnsDocuments = const bool.fromEnvironment(
        'YORKS_V1_RETURNS_DOCUMENTS',
        defaultValue: true,
      ),
      _documents = const bool.fromEnvironment(
        'YORKS_V1_DOCUMENTS',
        defaultValue: true,
      ),
      _teamChat = const bool.fromEnvironment(
        'YORKS_R38_TEAM_CHAT',
        defaultValue: false,
      ),
      _inventorySuppliers = const bool.fromEnvironment(
        'YORKS_R38_9_INVENTORY_SUPPLIERS',
        defaultValue: false,
      );

  final bool _foundation;
  final bool _projects;
  final bool _boq;
  final bool _excel;
  final bool _requests;
  final bool _arrangement;
  final bool _legacyArrangementReview;
  final bool _logistics;
  final bool _returnsDocuments;
  final bool _documents;
  final bool _teamChat;
  final bool _inventorySuppliers;

  bool get foundation => _foundation;
  bool get projects => foundation && _projects;
  bool get boq => projects && _boq;
  bool get excel => boq && _excel;
  bool get requests => excel && _requests;
  bool get arrangement => requests && _arrangement;

  /// Compatibility-only controls for arrangements saved before request-first
  /// approval was introduced. New arrangements are dispatch-ready immediately
  /// after Procurement saves them, so production keeps this surface disabled.
  bool get legacyArrangementReview => arrangement && _legacyArrangementReview;

  bool get logistics => arrangement && _logistics;
  bool get returnsDocuments => logistics && _returnsDocuments;
  bool get documents => returnsDocuments && _documents;
  bool get teamChat => documents && _teamChat;

  /// Supplier folders include controlled receipt evidence, so the feature
  /// cannot be enabled with only the stock kernel. Keeping the secure document
  /// dependency in the effective getter prevents a partially functional
  /// supplier workspace from reaching users.
  bool get inventorySuppliers => documents && _inventorySuppliers;

  /// The one supported Yorks V1 R35 operational chain. Release builds must
  /// fail closed if a caller explicitly disables any dependency in this chain.
  bool get isCompleteR35 => documents;
}
