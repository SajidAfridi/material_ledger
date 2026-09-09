const int analyticsSchemaVersion = 1;

/// The complete Yorks product-analytics event allowlist. New events must be
/// reviewed here and documented before a call site can emit them.
enum AnalyticsEvent {
  authenticationAttempted,
  authenticationSucceeded,
  authenticationFailed,
  sessionRestored,
  userSignedOut,
  projectCreationStarted,
  projectCreationValidationFailed,
  projectCreationAttempted,
  projectCreated,
  projectCreationFailed,
  projectOpened,
  projectAccessChanged,
  projectUpdated,
  projectUpdateFailed,
  documentUploadAttempted,
  documentUploadSucceeded,
  documentUploadFailed,
  materialRequestStarted,
  materialRequestItemChanged,
  materialRequestDraftSaved,
  materialRequestReviewOpened,
  materialRequestValidationFailed,
  materialRequestSubmissionAttempted,
  materialRequestSubmitted,
  materialRequestSubmissionFailed,
  materialRequestOpened,
  materialRequestActionStarted,
  materialRequestActionCompleted,
  approvalOpened,
  approvalActionStarted,
  approvalActionCompleted,
  procurementRequestOpened,
  arrangementStarted,
  arrangementSaveAttempted,
  arrangementSaveCompleted,
  dispatchAttempted,
  dispatchCompleted,
  inventoryOpened,
  materialSearchCompleted,
  inventoryItemSelected,
  inventoryActionStarted,
  inventoryActionCompleted,
  inventoryImportCompleted,
  materialSearchStruggleDetected,
  uiRepeatedActionDetected,
  uiActionNoFeedback,
  operationCompleted,
  featureFlagInteracted,
  reliabilityError;

  String get wireName => _snakeCase(name);
}

enum AnalyticsProperty {
  schemaVersion,
  appVersion,
  appBuild,
  environment,
  platform,
  role,
  screenName,
  source,
  actionType,
  objectType,
  workflow,
  outcome,
  errorCategory,
  resultCount,
  itemCount,
  buildingCount,
  attachmentCount,
  durationMs,
  retryCount,
  attemptCount,
  noResultCount,
  tapCount,
  operationWasLoading,
  cached,
  success,
  featureFlag,
  variant,
  queryLengthBucket,
  fileType,
  fileSizeBucket,
  inventoryAction,
  arrangementMode,
  requestTiming,
  entryMode,
  listFilter,
  recordState,
  feedbackExpectedMs;

  String get wireName => _snakeCase(name);
}

typedef AnalyticsProperties = Map<AnalyticsProperty, Object?>;

enum AnalyticsScreen {
  splash,
  languageSelection,
  login,
  changePassword,
  dashboard,
  materials,
  projects,
  projectCreate,
  projectDetail,
  projectEdit,
  boqGroups,
  boqWorksheet,
  projectDocuments,
  materialRequests,
  materialRequestDraft,
  materialRequestDetail,
  procurementArrangement,
  logistics,
  returnsDocuments,
  inventory,
  inventoryImport,
  inventorySuppliers,
  inventorySupplierDetail,
  dispatches,
  returns,
  returnCreate,
  returnDetail,
  accounts,
  accountsProjects,
  accountsBilling,
  accountsClaims,
  accountsReceipts,
  accountsSupplierBills,
  accountsDocuments,
  accountsReports,
  accountsActivity,
  operationalAnalytics,
  workforce,
  workforceAdministration,
  workforceAttendance,
  workforceTimesheets,
  teamChat,
  teamChatConversation,
  configuration,
  userManagement,
  profile,
  notifications,
  notificationPreferences,
  rentals,
  people,
  browse,
  engineeringTool,
  settings,
  unknown;

  String get wireName => _snakeCase(name);
}

enum AnalyticsErrorCategory {
  invalidInput,
  unauthorized,
  offline,
  conflict,
  insufficientStock,
  featureDisabled,
  timeout,
  network,
  storage,
  backendUnavailable,
  unexpectedResponse,
  serverRejected,
  unknown;

  String get wireName => _snakeCase(name);
}

enum AnalyticsFeatureFlag {
  compactRequestWorkspace,
  streamlinedInventorySearch,
  projectCreationGuidance;

  String get wireName => 'yorks_${_snakeCase(name)}';
}

String analyticsWireName(Enum value) => _snakeCase(value.name);

String _snakeCase(String value) => value
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    )
    .toLowerCase();
