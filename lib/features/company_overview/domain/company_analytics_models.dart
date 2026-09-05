import '../../../shared/models/yorks_v1_domain_error.dart';

/// Bounded, server-supported filters for the company Analytics projection.
class CompanyAnalyticsFilters {
  const CompanyAnalyticsFilters({this.projectId, this.months = 6});

  final String? projectId;
  final int months;

  static const supportedMonths = <int>{3, 6, 12};

  Map<String, Object?> toRpcParameters() {
    if (!supportedMonths.contains(months)) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final normalizedProjectId = projectId?.trim();
    return {
      'p_project_id': normalizedProjectId == null || normalizedProjectId.isEmpty
          ? null
          : normalizedProjectId,
      'p_months': months,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CompanyAnalyticsFilters &&
      other.projectId == projectId &&
      other.months == months;

  @override
  int get hashCode => Object.hash(projectId, months);
}

enum CompanyAnalyticsCoverageState {
  available('available'),
  sourceOnly('source_only'),
  denied('denied');

  const CompanyAnalyticsCoverageState(this.wireValue);

  final String wireValue;

  static CompanyAnalyticsCoverageState fromWire(Object? value) {
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
}

class CompanyAnalyticsCoverageItem {
  const CompanyAnalyticsCoverageItem({
    required this.domain,
    required this.state,
    this.reason,
  });

  final String domain;
  final CompanyAnalyticsCoverageState state;
  final String? reason;
}

class CompanyProjectRegisterItem {
  const CompanyProjectRegisterItem({
    required this.projectId,
    required this.reference,
    required this.name,
    required this.state,
    required this.currentOwnerRole,
    required this.openRequestCount,
    required this.requestActionCount,
    required this.latestActivityAt,
    this.site,
    this.startDate,
    this.targetCompletionDate,
  });

  final String projectId;
  final String reference;
  final String name;
  final String? site;
  final String state;
  final String currentOwnerRole;
  final DateTime? startDate;
  final DateTime? targetCompletionDate;
  final int openRequestCount;
  final int requestActionCount;
  final DateTime latestActivityAt;

  factory CompanyProjectRegisterItem.fromJson(Map<String, dynamic> json) {
    final latest = DateTime.tryParse(
      _requiredString(json['latest_activity_at']),
    );
    if (latest == null) _unexpected();
    return CompanyProjectRegisterItem(
      projectId: _requiredString(json['project_id']),
      reference: _requiredString(json['project_reference']),
      name: _requiredString(json['project_name']),
      site: _optionalString(json['project_site']),
      state: _requiredString(json['state']),
      currentOwnerRole: _requiredString(json['current_owner_role']),
      startDate: _optionalDate(json['start_date']),
      targetCompletionDate: _optionalDate(json['target_completion_date']),
      openRequestCount: _count(json['open_request_count']),
      requestActionCount: _count(json['request_action_count']),
      latestActivityAt: latest.toUtc(),
    );
  }
}

class CompanyProjectAnalytics {
  CompanyProjectAnalytics({
    required this.total,
    required this.draft,
    required this.active,
    required this.onHold,
    required this.completed,
    required this.archived,
    List<CompanyProjectRegisterItem> register = const [],
  }) : register = List.unmodifiable(register);

  final int total;
  final int draft;
  final int active;
  final int onHold;
  final int completed;
  final int archived;
  final List<CompanyProjectRegisterItem> register;

  factory CompanyProjectAnalytics.fromJson(Map<String, dynamic> json) {
    final rawRegister = json['register'];
    if (rawRegister is! List) _unexpected();
    final value = CompanyProjectAnalytics(
      total: _count(json['total']),
      draft: _count(json['draft']),
      active: _count(json['active']),
      onHold: _count(json['on_hold']),
      completed: _count(json['completed']),
      archived: _count(json['archived']),
      register: rawRegister
          .map((raw) => CompanyProjectRegisterItem.fromJson(_map(raw)))
          .toList(growable: false),
    );
    if (value.total !=
            value.draft +
                value.active +
                value.onHold +
                value.completed +
                value.archived ||
        value.register.length > value.total ||
        value.register.length > 100) {
      _unexpected();
    }
    return value;
  }
}

class CompanyMaterialRequestMonth {
  const CompanyMaterialRequestMonth({
    required this.month,
    required this.submitted,
    required this.closed,
  });

  final String month;
  final int submitted;
  final int closed;

  factory CompanyMaterialRequestMonth.fromJson(Map<String, dynamic> json) =>
      CompanyMaterialRequestMonth(
        month: _month(json['month']),
        submitted: _count(json['submitted']),
        closed: _count(json['closed']),
      );
}

class CompanyMaterialRequestAttentionItem {
  CompanyMaterialRequestAttentionItem({
    required this.requestId,
    required this.requestNumber,
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.state,
    required this.timing,
    required this.currentOwnerRole,
    required this.nextActionCode,
    required this.actorCanAct,
    required List<String> exceptionCodes,
    required this.ageHours,
    required this.updatedAt,
    this.title,
    this.scheduledDate,
  }) : exceptionCodes = List.unmodifiable(exceptionCodes);

  final String requestId;
  final String requestNumber;
  final String? title;
  final String projectId;
  final String projectReference;
  final String projectName;
  final String state;
  final String timing;
  final DateTime? scheduledDate;
  final String currentOwnerRole;
  final String nextActionCode;
  final bool actorCanAct;
  final List<String> exceptionCodes;
  final double ageHours;
  final DateTime updatedAt;

  factory CompanyMaterialRequestAttentionItem.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawExceptions = json['exception_codes'];
    final updatedAt = DateTime.tryParse(_requiredString(json['updated_at']));
    final ageHours = _number(json['age_hours']);
    if (rawExceptions is! List || updatedAt == null || ageHours < 0) {
      _unexpected();
    }
    return CompanyMaterialRequestAttentionItem(
      requestId: _requiredString(json['request_id']),
      requestNumber: _requiredString(json['request_number']),
      title: _optionalString(json['title']),
      projectId: _requiredString(json['project_id']),
      projectReference: _requiredString(json['project_reference']),
      projectName: _requiredString(json['project_name']),
      state: _requiredString(json['state']),
      timing: _requiredString(json['timing']),
      scheduledDate: _optionalDate(json['scheduled_date']),
      currentOwnerRole: _requiredString(json['current_owner_role']),
      nextActionCode: _requiredString(json['next_action_code']),
      actorCanAct: _boolean(json['actor_can_act']),
      exceptionCodes: rawExceptions
          .map(_requiredString)
          .toList(growable: false),
      ageHours: ageHours,
      updatedAt: updatedAt.toUtc(),
    );
  }
}

class CompanyMaterialRequestAnalytics {
  CompanyMaterialRequestAnalytics({
    required this.total,
    required this.open,
    required this.needsAction,
    required this.drafts,
    required this.awaitingEngineeringApproval,
    required this.toArrange,
    required this.changesRequested,
    required this.dispatchReady,
    required this.receiptPending,
    required this.deliveryExceptions,
    required this.received,
    required this.closed,
    required this.cancelled,
    required List<CompanyMaterialRequestMonth> monthlyFlow,
    List<CompanyMaterialRequestAttentionItem> attention = const [],
  }) : monthlyFlow = List.unmodifiable(monthlyFlow),
       attention = List.unmodifiable(attention);

  final int total;
  final int open;
  final int needsAction;
  final int drafts;
  final int awaitingEngineeringApproval;
  final int toArrange;
  final int changesRequested;
  final int dispatchReady;
  final int receiptPending;
  final int deliveryExceptions;
  final int received;
  final int closed;
  final int cancelled;
  final List<CompanyMaterialRequestMonth> monthlyFlow;
  final List<CompanyMaterialRequestAttentionItem> attention;

  factory CompanyMaterialRequestAnalytics.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['monthly_flow'];
    final rawAttention = json['attention'];
    if (rawMonths is! List || rawAttention is! List) _unexpected();
    final value = CompanyMaterialRequestAnalytics(
      total: _count(json['total']),
      open: _count(json['open']),
      needsAction: _count(json['needs_action']),
      drafts: _count(json['drafts']),
      awaitingEngineeringApproval: _count(
        json['awaiting_engineering_approval'],
      ),
      toArrange: _count(json['to_arrange']),
      changesRequested: _count(json['changes_requested']),
      dispatchReady: _count(json['dispatch_ready']),
      receiptPending: _count(json['receipt_pending']),
      deliveryExceptions: _count(json['delivery_exceptions']),
      received: _count(json['received']),
      closed: _count(json['closed']),
      cancelled: _count(json['cancelled']),
      monthlyFlow: rawMonths
          .map((raw) => CompanyMaterialRequestMonth.fromJson(_map(raw)))
          .toList(growable: false),
      attention: rawAttention
          .map((raw) => CompanyMaterialRequestAttentionItem.fromJson(_map(raw)))
          .toList(growable: false),
    );
    if (value.total !=
            value.drafts +
                value.awaitingEngineeringApproval +
                value.toArrange +
                value.changesRequested +
                value.dispatchReady +
                value.receiptPending +
                value.received +
                value.closed +
                value.cancelled ||
        value.open !=
            value.awaitingEngineeringApproval +
                value.toArrange +
                value.changesRequested +
                value.dispatchReady +
                value.receiptPending ||
        value.needsAction > value.total ||
        value.deliveryExceptions > value.open ||
        value.attention.length > 12) {
      _unexpected();
    }
    return value;
  }
}

class CompanyAccountMonth {
  const CompanyAccountMonth({
    required this.month,
    required this.claimed,
    required this.certified,
    required this.received,
  });

  final String month;
  final String claimed;
  final String certified;
  final String received;

  factory CompanyAccountMonth.fromJson(Map<String, dynamic> json) =>
      CompanyAccountMonth(
        month: _month(json['month']),
        claimed: _decimal(json['claimed']),
        certified: _decimal(json['certified']),
        received: _decimal(json['received'], allowNegative: true),
      );
}

class CompanyAccountCurrency {
  CompanyAccountCurrency({
    required this.currencyCode,
    required this.projectCount,
    required this.contractValue,
    required this.claimed,
    required this.certified,
    required this.received,
    required this.outstanding,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.returnedCount,
    required this.pdcAttentionCount,
    required List<CompanyAccountMonth> monthlyFlow,
  }) : monthlyFlow = List.unmodifiable(monthlyFlow);

  final String currencyCode;
  final int projectCount;
  final String contractValue;
  final String claimed;
  final String certified;
  final String received;
  final String outstanding;
  final int overdueCount;
  final int dueSoonCount;
  final int returnedCount;
  final int pdcAttentionCount;
  final List<CompanyAccountMonth> monthlyFlow;

  int get attentionCount =>
      overdueCount + dueSoonCount + returnedCount + pdcAttentionCount;

  factory CompanyAccountCurrency.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['monthly_flow'];
    final currency = _requiredString(json['currency_code']);
    if (rawMonths is! List || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      _unexpected();
    }
    return CompanyAccountCurrency(
      currencyCode: currency,
      projectCount: _count(json['project_count']),
      contractValue: _decimal(json['contract_value']),
      claimed: _decimal(json['claimed']),
      certified: _decimal(json['certified']),
      received: _decimal(json['received']),
      outstanding: _decimal(json['outstanding']),
      overdueCount: _count(json['overdue_count']),
      dueSoonCount: _count(json['due_soon_count']),
      returnedCount: _count(json['returned_count']),
      pdcAttentionCount: _count(json['pdc_attention_count']),
      monthlyFlow: rawMonths
          .map((raw) => CompanyAccountMonth.fromJson(_map(raw)))
          .toList(growable: false),
    );
  }
}

class CompanyAccountAnalytics {
  CompanyAccountAnalytics({
    required this.authorizedProjectCount,
    required this.unconfiguredProjectCount,
    required this.attentionCount,
    required List<CompanyAccountCurrency> currencyGroups,
  }) : currencyGroups = List.unmodifiable(currencyGroups);

  final int authorizedProjectCount;
  final int unconfiguredProjectCount;
  final int attentionCount;
  final List<CompanyAccountCurrency> currencyGroups;

  factory CompanyAccountAnalytics.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['currency_groups'];
    if (rawGroups is! List) _unexpected();
    final groups = rawGroups
        .map((raw) => CompanyAccountCurrency.fromJson(_map(raw)))
        .toList(growable: false);
    if (groups.map((value) => value.currencyCode).toSet().length !=
        groups.length) {
      _unexpected();
    }
    final value = CompanyAccountAnalytics(
      authorizedProjectCount: _count(json['authorized_project_count']),
      unconfiguredProjectCount: _count(json['unconfigured_project_count']),
      attentionCount: _count(json['attention_count']),
      currencyGroups: groups,
    );
    if (value.unconfiguredProjectCount > value.authorizedProjectCount ||
        value.currencyGroups.fold<int>(
                  0,
                  (sum, group) => sum + group.projectCount,
                ) +
                value.unconfiguredProjectCount !=
            value.authorizedProjectCount ||
        value.currencyGroups.fold<int>(
              0,
              (sum, group) => sum + group.attentionCount,
            ) !=
            value.attentionCount) {
      _unexpected();
    }
    return value;
  }
}

class CompanyWorkforceMonth {
  const CompanyWorkforceMonth({
    required this.month,
    required this.regularMinutes,
    required this.overtimeMinutes,
  });

  final String month;
  final int regularMinutes;
  final int overtimeMinutes;

  factory CompanyWorkforceMonth.fromJson(Map<String, dynamic> json) =>
      CompanyWorkforceMonth(
        month: _month(json['month']),
        regularMinutes: _count(json['regular_minutes']),
        overtimeMinutes: _count(json['overtime_minutes']),
      );
}

class CompanyWorkforceAnalytics {
  CompanyWorkforceAnalytics({
    required this.activeWorkerCount,
    required this.activeSupervisorCount,
    required this.missingTodayCount,
    required this.monthlyPendingCount,
    required this.returnedCount,
    required this.awaitingFinalCount,
    required this.lockedCount,
    required this.reopenRequestCount,
    required this.configurationIssueCount,
    required this.confirmedPeriodCount,
    required this.confirmedRegularMinutes,
    required this.confirmedOvertimeMinutes,
    required List<CompanyWorkforceMonth> monthlyFlow,
  }) : monthlyFlow = List.unmodifiable(monthlyFlow);

  final int activeWorkerCount;
  final int activeSupervisorCount;
  final int missingTodayCount;
  final int monthlyPendingCount;
  final int returnedCount;
  final int awaitingFinalCount;
  final int lockedCount;
  final int reopenRequestCount;
  final int configurationIssueCount;
  final int confirmedPeriodCount;
  final int confirmedRegularMinutes;
  final int confirmedOvertimeMinutes;
  final List<CompanyWorkforceMonth> monthlyFlow;

  int get attentionCount =>
      missingTodayCount +
      monthlyPendingCount +
      returnedCount +
      awaitingFinalCount +
      reopenRequestCount +
      configurationIssueCount;

  factory CompanyWorkforceAnalytics.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['monthly_flow'];
    if (rawMonths is! List) _unexpected();
    final value = CompanyWorkforceAnalytics(
      activeWorkerCount: _count(json['active_worker_count']),
      activeSupervisorCount: _count(json['active_supervisor_count']),
      missingTodayCount: _count(json['missing_today_count']),
      monthlyPendingCount: _count(json['monthly_pending_count']),
      returnedCount: _count(json['returned_count']),
      awaitingFinalCount: _count(json['awaiting_final_count']),
      lockedCount: _count(json['locked_count']),
      reopenRequestCount: _count(json['reopen_request_count']),
      configurationIssueCount: _count(json['configuration_issue_count']),
      confirmedPeriodCount: _count(json['confirmed_period_count']),
      confirmedRegularMinutes: _count(json['confirmed_regular_minutes']),
      confirmedOvertimeMinutes: _count(json['confirmed_overtime_minutes']),
      monthlyFlow: rawMonths
          .map((raw) => CompanyWorkforceMonth.fromJson(_map(raw)))
          .toList(growable: false),
    );
    if (value.confirmedRegularMinutes !=
            value.monthlyFlow.fold<int>(
              0,
              (sum, month) => sum + month.regularMinutes,
            ) ||
        value.confirmedOvertimeMinutes !=
            value.monthlyFlow.fold<int>(
              0,
              (sum, month) => sum + month.overtimeMinutes,
            )) {
      _unexpected();
    }
    return value;
  }
}

class CompanyRentalMonth {
  const CompanyRentalMonth({required this.month, required this.collected});

  final String month;
  final String collected;

  factory CompanyRentalMonth.fromJson(Map<String, dynamic> json) =>
      CompanyRentalMonth(
        month: _month(json['month']),
        collected: _decimal(json['collected']),
      );
}

class CompanyRentalAnalytics {
  CompanyRentalAnalytics({
    required this.currencyCode,
    required this.totalProperties,
    required this.occupied,
    required this.monthlyRentRoll,
    required this.collectedThisMonth,
    required this.outstanding,
    required this.securityDeposits,
    required this.expiringWithin90,
    required this.chequeAttention,
    required List<CompanyRentalMonth> monthlyFlow,
  }) : monthlyFlow = List.unmodifiable(monthlyFlow);

  final String currencyCode;
  final int totalProperties;
  final int occupied;
  final String monthlyRentRoll;
  final String collectedThisMonth;
  final String outstanding;
  final String securityDeposits;
  final int expiringWithin90;
  final int chequeAttention;
  final List<CompanyRentalMonth> monthlyFlow;

  int get attentionCount => expiringWithin90 + chequeAttention;
  double get occupancyPercent =>
      totalProperties == 0 ? 0 : occupied / totalProperties * 100;

  factory CompanyRentalAnalytics.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['monthly_flow'];
    final currency = _requiredString(json['currency_code']);
    if (rawMonths is! List || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      _unexpected();
    }
    final value = CompanyRentalAnalytics(
      currencyCode: currency,
      totalProperties: _count(json['total_properties']),
      occupied: _count(json['occupied']),
      monthlyRentRoll: _decimal(json['monthly_rent_roll']),
      collectedThisMonth: _decimal(json['collected_this_month']),
      outstanding: _decimal(json['outstanding']),
      securityDeposits: _decimal(json['security_deposits']),
      expiringWithin90: _count(json['expiring_within_90']),
      chequeAttention: _count(json['cheque_attention']),
      monthlyFlow: rawMonths
          .map((raw) => CompanyRentalMonth.fromJson(_map(raw)))
          .toList(growable: false),
    );
    if (value.occupied > value.totalProperties) _unexpected();
    return value;
  }
}

class CompanyAnalyticsProjection {
  CompanyAnalyticsProjection({
    required this.generatedAt,
    required this.projectId,
    required this.months,
    required this.timezone,
    required this.isPartial,
    required Map<String, CompanyAnalyticsCoverageItem> coverage,
    required List<String> warnings,
    this.projects,
    this.materialRequests,
    this.accounts,
    this.workforce,
    this.rentals,
  }) : coverage = Map.unmodifiable(coverage),
       warnings = List.unmodifiable(warnings);

  final DateTime generatedAt;
  final String? projectId;
  final int months;
  final String timezone;
  final bool isPartial;
  final Map<String, CompanyAnalyticsCoverageItem> coverage;
  final List<String> warnings;
  final CompanyProjectAnalytics? projects;
  final CompanyMaterialRequestAnalytics? materialRequests;
  final CompanyAccountAnalytics? accounts;
  final CompanyWorkforceAnalytics? workforce;
  final CompanyRentalAnalytics? rentals;

  int get importantActionCount =>
      (materialRequests?.needsAction ?? 0) +
      (accounts?.attentionCount ?? 0) +
      (workforce?.attentionCount ?? 0) +
      (rentals?.attentionCount ?? 0);

  factory CompanyAnalyticsProjection.fromRpcJson(Map<String, dynamic> json) {
    if (_integer(json['schema_version']) != 2) _unexpected();
    final generatedAt = DateTime.tryParse(
      _requiredString(json['generated_at']),
    );
    final effective = _map(json['effective_filters']);
    final asOf = _map(json['as_of']);
    final coverageJson = _map(json['coverage']);
    if (generatedAt == null || json['is_partial'] is! bool) _unexpected();
    final generatedAtUtc = generatedAt.toUtc();

    const requiredCoverageDomains = <String>{
      'projects',
      'material_requests',
      'accounts',
      'workforce',
      'rentals',
      'inventory',
      'audit',
    };
    if (coverageJson.length != requiredCoverageDomains.length ||
        !requiredCoverageDomains.every(coverageJson.containsKey)) {
      _unexpected();
    }

    final coverage = <String, CompanyAnalyticsCoverageItem>{};
    for (final entry in coverageJson.entries) {
      final item = _map(entry.value);
      final state = CompanyAnalyticsCoverageState.fromWire(item['state']);
      final reason = _optionalString(item['reason']);
      if ((state == CompanyAnalyticsCoverageState.available) !=
          (reason == null)) {
        _unexpected();
      }
      coverage[entry.key] = CompanyAnalyticsCoverageItem(
        domain: entry.key,
        state: state,
        reason: reason,
      );
    }

    final projects = _parseAvailable(
      json,
      coverage,
      'projects',
      CompanyProjectAnalytics.fromJson,
    );
    final requests = _parseAvailable(
      json,
      coverage,
      'material_requests',
      CompanyMaterialRequestAnalytics.fromJson,
    );
    final accounts = _parseAvailable(
      json,
      coverage,
      'accounts',
      CompanyAccountAnalytics.fromJson,
    );
    final workforce = _parseAvailable(
      json,
      coverage,
      'workforce',
      CompanyWorkforceAnalytics.fromJson,
    );
    final rentals = _parseAvailable(
      json,
      coverage,
      'rentals',
      CompanyRentalAnalytics.fromJson,
    );

    final rawWarnings = json['warnings'];
    if (rawWarnings is! List) _unexpected();
    final months = _count(effective['months']);
    final timezone = _requiredString(effective['timezone']);
    final isPartial = json['is_partial'] as bool;
    if (!CompanyAnalyticsFilters.supportedMonths.contains(months) ||
        timezone != 'UTC' ||
        _requiredString(asOf['timezone']) != timezone ||
        _count(asOf['month_count']) != months ||
        isPartial !=
            coverage.values.any(
              (item) => item.state != CompanyAnalyticsCoverageState.available,
            )) {
      _unexpected();
    }

    final expectedMonths = <String>[
      for (var index = months - 1; index >= 0; index--)
        _monthKey(
          DateTime.utc(generatedAtUtc.year, generatedAtUtc.month - index),
        ),
    ];
    _validateMonths(
      requests?.monthlyFlow.map((value) => value.month),
      expectedMonths,
    );
    for (final group
        in accounts?.currencyGroups ?? const <CompanyAccountCurrency>[]) {
      _validateMonths(
        group.monthlyFlow.map((value) => value.month),
        expectedMonths,
      );
    }
    _validateMonths(
      workforce?.monthlyFlow.map((value) => value.month),
      expectedMonths,
    );
    _validateMonths(
      rentals?.monthlyFlow.map((value) => value.month),
      expectedMonths,
    );

    return CompanyAnalyticsProjection(
      generatedAt: generatedAtUtc,
      projectId: _optionalString(effective['project_id']),
      months: months,
      timezone: timezone,
      isPartial: isPartial,
      coverage: coverage,
      warnings: rawWarnings
          .map((warning) {
            final value = _map(warning);
            return '${_requiredString(value['code'])}:${_requiredString(value['domain'])}';
          })
          .toList(growable: false),
      projects: projects,
      materialRequests: requests,
      accounts: accounts,
      workforce: workforce,
      rentals: rentals,
    );
  }
}

T? _parseAvailable<T>(
  Map<String, dynamic> json,
  Map<String, CompanyAnalyticsCoverageItem> coverage,
  String key,
  T Function(Map<String, dynamic>) parser,
) {
  if (coverage[key]?.state == CompanyAnalyticsCoverageState.available) {
    return parser(_map(json[key]));
  }
  if (json.containsKey(key)) _unexpected();
  return null;
}

void _validateMonths(Iterable<String>? actual, List<String> expected) {
  if (actual == null) return;
  final values = actual.toList(growable: false);
  if (values.length != expected.length || !_sameStrings(values, expected)) {
    _unexpected();
  }
}

String _month(Object? value) {
  final month = _requiredString(value);
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) _unexpected();
  return month;
}

String _monthKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

bool _sameStrings(List<String> left, List<String> right) {
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) _unexpected();
  return Map<String, dynamic>.from(value);
}

int _integer(Object? value) => switch (value) {
  int value => value,
  num value when value.isFinite && value == value.roundToDouble() =>
    value.toInt(),
  String value => int.tryParse(value) ?? -1,
  _ => -1,
};

int _count(Object? value) {
  final result = _integer(value);
  if (result < 0) _unexpected();
  return result;
}

double _number(Object? value) {
  final result = switch (value) {
    num value when value.isFinite => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  if (result == null || !result.isFinite) _unexpected();
  return result;
}

bool _boolean(Object? value) {
  if (value is! bool) _unexpected();
  return value;
}

String _decimal(Object? value, {bool allowNegative = false}) {
  final text = switch (value) {
    String value => value.trim(),
    int value => value.toString(),
    num value when value.isFinite => value.toString(),
    _ => '',
  };
  final pattern = allowNegative
      ? RegExp(r'^-?\d+(?:\.\d+)?$')
      : RegExp(r'^\d+(?:\.\d+)?$');
  if (!pattern.hasMatch(text)) _unexpected();
  return text;
}

String _requiredString(Object? value) {
  if (value is! String || value.trim().isEmpty) _unexpected();
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) _unexpected();
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _optionalDate(Object? value) {
  final text = _optionalString(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) _unexpected();
  return parsed;
}

Never _unexpected() => throw const YorksV1DomainException(
  YorksV1DomainErrorCode.unexpectedResponse,
);
