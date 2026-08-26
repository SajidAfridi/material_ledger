import 'accounts_decimal.dart';

final class YorksAccountsPortfolioFilters {
  const YorksAccountsPortfolioFilters({
    this.projectId,
    this.client,
    this.commercialState,
    this.dueState,
    this.paymentState,
    this.pdcState,
    this.supplierMatchState,
    this.search,
    this.beforeActivityAt,
    this.beforeProjectId,
    this.limit = 25,
  });

  final String? projectId;
  final String? client;
  final String? commercialState;
  final String? dueState;
  final String? paymentState;
  final String? pdcState;
  final String? supplierMatchState;
  final String? search;
  final DateTime? beforeActivityAt;
  final String? beforeProjectId;
  final int limit;

  YorksAccountsPortfolioFilters copyWith({
    String? projectId,
    String? client,
    String? commercialState,
    String? dueState,
    String? paymentState,
    String? pdcState,
    String? supplierMatchState,
    String? search,
    DateTime? beforeActivityAt,
    String? beforeProjectId,
    int? limit,
    bool clearCursor = false,
  }) => YorksAccountsPortfolioFilters(
    projectId: projectId ?? this.projectId,
    client: client ?? this.client,
    commercialState: commercialState ?? this.commercialState,
    dueState: dueState ?? this.dueState,
    paymentState: paymentState ?? this.paymentState,
    pdcState: pdcState ?? this.pdcState,
    supplierMatchState: supplierMatchState ?? this.supplierMatchState,
    search: search ?? this.search,
    beforeActivityAt: clearCursor
        ? null
        : beforeActivityAt ?? this.beforeActivityAt,
    beforeProjectId: clearCursor
        ? null
        : beforeProjectId ?? this.beforeProjectId,
    limit: limit ?? this.limit,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_project_id': _trim(projectId),
    'p_client': _trim(client),
    'p_commercial_state': _trim(commercialState),
    'p_due_state': _trim(dueState),
    'p_payment_state': _trim(paymentState),
    'p_pdc_state': _trim(pdcState),
    'p_supplier_match_state': _trim(supplierMatchState),
    'p_search': _trim(search),
    'p_before_activity_at': beforeActivityAt?.toUtc().toIso8601String(),
    'p_before_project_id': _trim(beforeProjectId),
    'p_limit': limit,
  };

  bool get hasActiveFilter => [
    projectId,
    client,
    commercialState,
    dueState,
    paymentState,
    pdcState,
    supplierMatchState,
    search,
  ].any((value) => _trim(value) != null);
}

final class YorksAccountsPortfolioTotals {
  const YorksAccountsPortfolioTotals({
    required this.projectCount,
    required this.contractBaseline,
    required this.confirmedEligible,
    required this.availableToClaim,
    required this.claimed,
    required this.certified,
    required this.amountPaidTillDate,
    required this.stillDue,
    required this.pdcExposure,
    required this.actionCount,
  });

  final int projectCount;
  final YorksAccountsDecimal contractBaseline;
  final YorksAccountsDecimal confirmedEligible;
  final YorksAccountsDecimal availableToClaim;
  final YorksAccountsDecimal claimed;
  final YorksAccountsDecimal certified;
  final YorksAccountsDecimal amountPaidTillDate;
  final YorksAccountsDecimal stillDue;
  final YorksAccountsDecimal pdcExposure;
  final int actionCount;

  factory YorksAccountsPortfolioTotals.fromRpcJson(Map<String, dynamic> json) =>
      YorksAccountsPortfolioTotals(
        projectCount: _int(json, 'project_count'),
        contractBaseline: _decimal(json, 'contract_baseline'),
        confirmedEligible: _decimal(json, 'confirmed_eligible'),
        availableToClaim: _decimal(json, 'available_to_claim'),
        claimed: _decimal(json, 'claimed'),
        certified: _decimal(json, 'certified'),
        amountPaidTillDate: _decimal(json, 'amount_paid_till_date'),
        stillDue: _decimal(json, 'still_due'),
        pdcExposure: _decimal(json, 'pdc_exposure'),
        actionCount: _int(json, 'action_count'),
      );
}

final class YorksAccountsPortfolioProject {
  const YorksAccountsPortfolioProject({
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.projectSite,
    required this.projectState,
    required this.clientName,
    required this.baselineRevisionNumber,
    required this.currencyCode,
    required this.contractBaseline,
    required this.confirmedEligible,
    required this.availableToClaim,
    required this.claimed,
    required this.certified,
    required this.amountPaidTillDate,
    required this.stillDue,
    required this.pdcExposure,
    required this.confirmedPercent,
    required this.dueState,
    required this.paymentState,
    required this.actionCount,
    required this.latestActivityAt,
    required this.supplierReviewCount,
    required this.supplierOpenAmount,
  });

  final String projectId;
  final String projectReference;
  final String projectName;
  final String? projectSite;
  final String projectState;
  final String? clientName;
  final int? baselineRevisionNumber;
  final String? currencyCode;
  final YorksAccountsDecimal contractBaseline;
  final YorksAccountsDecimal confirmedEligible;
  final YorksAccountsDecimal availableToClaim;
  final YorksAccountsDecimal claimed;
  final YorksAccountsDecimal certified;
  final YorksAccountsDecimal amountPaidTillDate;
  final YorksAccountsDecimal stillDue;
  final YorksAccountsDecimal pdcExposure;
  final YorksAccountsDecimal confirmedPercent;
  final String dueState;
  final String paymentState;
  final int actionCount;
  final DateTime latestActivityAt;
  final int? supplierReviewCount;
  final YorksAccountsDecimal? supplierOpenAmount;

  factory YorksAccountsPortfolioProject.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksAccountsPortfolioProject(
    projectId: _string(json, 'project_id'),
    projectReference: _string(json, 'project_reference'),
    projectName: _string(json, 'project_name'),
    projectSite: _optionalString(json['project_site']),
    projectState: _string(json, 'project_state'),
    clientName: _optionalString(json['client_name']),
    baselineRevisionNumber: _optionalInt(json['baseline_revision_number']),
    currencyCode: _optionalString(json['currency_code']),
    contractBaseline: _decimal(json, 'contract_baseline'),
    confirmedEligible: _decimal(json, 'confirmed_eligible'),
    availableToClaim: _decimal(json, 'available_to_claim'),
    claimed: _decimal(json, 'claimed'),
    certified: _decimal(json, 'certified'),
    amountPaidTillDate: _decimal(json, 'amount_paid_till_date'),
    stillDue: _decimal(json, 'still_due'),
    pdcExposure: _decimal(json, 'pdc_exposure'),
    confirmedPercent: _decimal(json, 'confirmed_percent'),
    dueState: _string(json, 'due_state'),
    paymentState: _string(json, 'payment_state'),
    actionCount: _int(json, 'action_count'),
    latestActivityAt: _dateTime(json, 'latest_activity_at'),
    supplierReviewCount: _optionalInt(json['supplier_review_count']),
    supplierOpenAmount: json.containsKey('supplier_open_amount')
        ? _decimal(json, 'supplier_open_amount')
        : null,
  );
}

final class YorksAccountsActionItem {
  const YorksAccountsActionItem({
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.code,
    required this.ownerRole,
    required this.severity,
    required this.count,
    required this.occurredAt,
  });

  final String projectId;
  final String projectReference;
  final String projectName;
  final String code;
  final String ownerRole;
  final String severity;
  final int count;
  final DateTime occurredAt;

  factory YorksAccountsActionItem.fromRpcJson(Map<String, dynamic> json) =>
      YorksAccountsActionItem(
        projectId: _string(json, 'project_id'),
        projectReference: _string(json, 'project_reference'),
        projectName: _string(json, 'project_name'),
        code: _string(json, 'code'),
        ownerRole: _string(json, 'owner_role'),
        severity: _string(json, 'severity'),
        count: _int(json, 'count'),
        occurredAt: _dateTime(json, 'occurred_at'),
      );
}

final class YorksAccountsPortfolioProjection {
  YorksAccountsPortfolioProjection({
    required this.actorExactRole,
    required this.canExport,
    required this.authorizedProjectCount,
    required this.filteredProjectCount,
    required this.totals,
    required List<YorksAccountsPortfolioProject> projects,
    required List<YorksAccountsActionItem> actionQueue,
    required this.nextActivityAt,
    required this.nextProjectId,
  }) : projects = List.unmodifiable(projects),
       actionQueue = List.unmodifiable(actionQueue);

  final String actorExactRole;
  final bool canExport;
  final int authorizedProjectCount;
  final int filteredProjectCount;
  final YorksAccountsPortfolioTotals totals;
  final List<YorksAccountsPortfolioProject> projects;
  final List<YorksAccountsActionItem> actionQueue;
  final DateTime? nextActivityAt;
  final String? nextProjectId;

  YorksAccountsPortfolioProjection append(
    YorksAccountsPortfolioProjection next,
  ) {
    if (actorExactRole != next.actorExactRole ||
        canExport != next.canExport ||
        authorizedProjectCount != next.authorizedProjectCount ||
        filteredProjectCount != next.filteredProjectCount ||
        !_sameTotals(totals, next.totals)) {
      throw const FormatException(
        'Accounts portfolio page does not match the active result set.',
      );
    }
    final projectsById = <String, YorksAccountsPortfolioProject>{
      for (final project in projects) project.projectId: project,
      for (final project in next.projects) project.projectId: project,
    };
    return YorksAccountsPortfolioProjection(
      actorExactRole: actorExactRole,
      canExport: canExport,
      authorizedProjectCount: authorizedProjectCount,
      filteredProjectCount: filteredProjectCount,
      totals: totals,
      projects: projectsById.values.toList(growable: false),
      actionQueue: actionQueue,
      nextActivityAt: next.nextActivityAt,
      nextProjectId: next.nextProjectId,
    );
  }

  factory YorksAccountsPortfolioProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    if (_int(json, 'schema_version') != 2 || json['scope'] != 'portfolio') {
      throw const FormatException('Unsupported Accounts portfolio response.');
    }
    final cursor = _optionalMap(json['next_cursor']);
    return YorksAccountsPortfolioProjection(
      actorExactRole: _string(json, 'actor_exact_role'),
      canExport: _bool(json, 'can_export'),
      authorizedProjectCount: _int(json, 'authorized_project_count'),
      filteredProjectCount: _int(json, 'filtered_project_count'),
      totals: YorksAccountsPortfolioTotals.fromRpcJson(_map(json, 'totals')),
      projects: _mapList(
        json['projects'],
      ).map(YorksAccountsPortfolioProject.fromRpcJson).toList(growable: false),
      actionQueue: _mapList(
        json['action_queue'],
      ).map(YorksAccountsActionItem.fromRpcJson).toList(growable: false),
      nextActivityAt: cursor == null
          ? null
          : _dateTime(cursor, 'before_activity_at'),
      nextProjectId: cursor == null
          ? null
          : _string(cursor, 'before_project_id'),
    );
  }
}

bool _sameTotals(
  YorksAccountsPortfolioTotals left,
  YorksAccountsPortfolioTotals right,
) =>
    left.projectCount == right.projectCount &&
    left.contractBaseline == right.contractBaseline &&
    left.confirmedEligible == right.confirmedEligible &&
    left.availableToClaim == right.availableToClaim &&
    left.claimed == right.claimed &&
    left.certified == right.certified &&
    left.amountPaidTillDate == right.amountPaidTillDate &&
    left.stillDue == right.stillDue &&
    left.pdcExposure == right.pdcExposure &&
    left.actionCount == right.actionCount;

final class YorksAccountsProjectUiCapabilities {
  const YorksAccountsProjectUiCapabilities({
    required this.viewProjectAccounts,
    required this.viewValues,
    required this.viewSupplierCosts,
    required this.suggestProgress,
    required this.confirmProgress,
    required this.prepareClaim,
    required this.manageInvoices,
    required this.manageSupplierBills,
    required this.approveSupplierPayment,
    required this.canExport,
  });

  final bool viewProjectAccounts;
  final bool viewValues;
  final bool viewSupplierCosts;
  final bool suggestProgress;
  final bool confirmProgress;
  final bool prepareClaim;
  final bool manageInvoices;
  final bool manageSupplierBills;
  final bool approveSupplierPayment;
  final bool canExport;

  factory YorksAccountsProjectUiCapabilities.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksAccountsProjectUiCapabilities(
    viewProjectAccounts: _bool(json, 'view_project_accounts'),
    viewValues: _bool(json, 'view_project_commercial_values'),
    viewSupplierCosts: _bool(json, 'view_supplier_costs'),
    suggestProgress: _bool(json, 'suggest_billing_progress'),
    confirmProgress: _bool(json, 'confirm_billing_progress'),
    prepareClaim: _bool(json, 'prepare_client_claim'),
    manageInvoices: _bool(json, 'manage_client_invoices'),
    manageSupplierBills: _bool(json, 'manage_supplier_bills'),
    approveSupplierPayment: _bool(json, 'approve_supplier_bill_payment'),
    canExport: _bool(json, 'export_accounts_registers'),
  );
}

final class YorksAccountsProjectOverviewProjection {
  const YorksAccountsProjectOverviewProjection({
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.projectSite,
    required this.clientName,
    required this.actorExactRole,
    required this.capabilities,
    required this.baseline,
    required this.progress,
    required this.receivables,
    required this.supplier,
  });

  final String projectId;
  final String projectReference;
  final String projectName;
  final String? projectSite;
  final String? clientName;
  final String actorExactRole;
  final YorksAccountsProjectUiCapabilities capabilities;
  final Map<String, dynamic>? baseline;
  final Map<String, dynamic>? progress;
  final Map<String, dynamic>? receivables;
  final Map<String, dynamic>? supplier;

  factory YorksAccountsProjectOverviewProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    if (_int(json, 'schema_version') != 2) {
      throw const FormatException('Unsupported project Accounts response.');
    }
    final capabilities = YorksAccountsProjectUiCapabilities.fromRpcJson(
      _map(json, 'capabilities'),
    );
    if (capabilities.viewValues && !capabilities.viewProjectAccounts) {
      throw const FormatException('Commercial values require project access.');
    }
    if (!capabilities.viewValues &&
        (json.containsKey('receivables') ||
            (_optionalMap(json['baseline'])?.containsKey('contract_value') ??
                false))) {
      throw const FormatException('Protected Accounts values were leaked.');
    }
    if (!capabilities.viewProjectAccounts &&
        (json.containsKey('baseline') || json.containsKey('progress'))) {
      throw const FormatException('Protected project Accounts data leaked.');
    }
    if (!capabilities.viewSupplierCosts && json.containsKey('supplier')) {
      throw const FormatException('Protected supplier values were leaked.');
    }
    if (capabilities.viewProjectAccounts &&
        (!json.containsKey('baseline') || !json.containsKey('progress'))) {
      throw const FormatException('Project Accounts response is incomplete.');
    }
    if (capabilities.viewValues && !json.containsKey('receivables')) {
      throw const FormatException('Receivables response is incomplete.');
    }
    if (capabilities.viewSupplierCosts && !json.containsKey('supplier')) {
      throw const FormatException('Supplier response is incomplete.');
    }
    final baseline = _optionalMap(json['baseline']);
    final progress = _optionalMap(json['progress']);
    final receivables = _optionalMap(json['receivables']);
    final supplier = _optionalMap(json['supplier']);
    _validateProjectSections(
      capabilities: capabilities,
      baseline: baseline,
      progress: progress,
      receivables: receivables,
      supplier: supplier,
    );
    return YorksAccountsProjectOverviewProjection(
      projectId: _string(json, 'project_id'),
      projectReference: _string(json, 'project_reference'),
      projectName: _string(json, 'project_name'),
      projectSite: _optionalString(json['project_site']),
      clientName: _optionalString(json['client_name']),
      actorExactRole: _string(json, 'actor_exact_role'),
      capabilities: capabilities,
      baseline: baseline,
      progress: progress,
      receivables: receivables,
      supplier: supplier,
    );
  }
}

void _validateProjectSections({
  required YorksAccountsProjectUiCapabilities capabilities,
  required Map<String, dynamic>? baseline,
  required Map<String, dynamic>? progress,
  required Map<String, dynamic>? receivables,
  required Map<String, dynamic>? supplier,
}) {
  if (baseline != null) {
    _string(baseline, 'revision_id');
    _int(baseline, 'revision_number');
    _string(baseline, 'status');
    _dateTime(baseline, 'effective_at');
    if (capabilities.viewValues) {
      _decimal(baseline, 'contract_value');
      _string(baseline, 'currency_code');
      _int(baseline, 'payment_terms_days');
      _int(baseline, 'reminder_lead_days');
    }
  }
  if (progress != null) {
    _decimal(progress, 'confirmed_percent');
    _decimal(progress, 'suggested_percent');
    _int(progress, 'pending_review_count');
    final positions = _mapList(progress['building_position']);
    for (final position in positions) {
      _string(position, 'building_scope_id');
      _string(position, 'building_name');
      _decimal(position, 'confirmed_percent');
      _decimal(position, 'suggested_percent');
      _string(position, 'stage_key');
      _string(position, 'stage_name');
      _string(position, 'review_status');
      _string(position, 'action_owner');
      _dateTime(position, 'updated_at');
    }
    if (capabilities.viewValues) _decimal(progress, 'confirmed_eligible');
  }
  if (receivables != null) {
    for (final key in const <String>[
      'claimed',
      'certified',
      'amount_paid_till_date',
      'still_due',
      'pdc_exposure',
    ]) {
      _decimal(receivables, key);
    }
    final invoices = _mapList(receivables['recent_invoices']);
    for (final invoice in invoices) {
      _string(invoice, 'invoice_id');
      _string(invoice, 'invoice_reference');
      _string(invoice, 'status');
      _decimal(invoice, 'claimed_ex_vat');
      _decimal(invoice, 'certified_incl_vat');
      _decimal(invoice, 'amount_paid_till_date');
      _decimal(invoice, 'still_due');
      _dateTime(invoice, 'updated_at');
    }
  }
  if (supplier != null) {
    _int(supplier, 'total_bills');
    _int(supplier, 'needs_review');
    _decimal(supplier, 'commitments');
    _decimal(supplier, 'paid');
    _decimal(supplier, 'open_amount');
  }
}

String? _trim(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.', value);
  }
  return value;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.', value);
  return value;
}

int? _optionalInt(Object? value) => value is int ? value : null;

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.', value);
  return value;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final raw = _string(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null) throw FormatException('$key must be a timestamp.', raw);
  return value;
}

YorksAccountsDecimal _decimal(Map<String, dynamic> json, String key) =>
    YorksAccountsDecimal.fromRpcValue(json[key], key: key);

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be an object.', value);
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic>? _optionalMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) throw FormatException('Expected a JSON list.', value);
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('Expected a JSON object.', item);
        }
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}
