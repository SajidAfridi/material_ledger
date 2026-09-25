import 'app_strings.dart';
import 'app_language.dart';
import 'yorks_v1_domain_error.dart';
import 'yorks_v1_material_request.dart';
import 'yorks_v1_material_request_strings.dart';
import 'yorks_v1_company_material_request_strings.dart';

/// Register-only union. Company records never acquire Project IDs, lines or
/// command capabilities by being displayed next to Project requests.
class YorksV1MaterialRegisterEntry {
  YorksV1MaterialRegisterEntry.project(YorksV1MaterialRequest request)
    : projectRequest = request,
      _company = null;
  YorksV1MaterialRegisterEntry.company(Map<String, dynamic> value)
    : _company = Map.unmodifiable(value),
      projectRequest = null {
    for (final key in [
      'id',
      'state',
      'category_name',
      'responsible_unit_name',
      'created_at',
      'updated_at',
    ]) {
      if (value[key] is! String || (value[key] as String).isEmpty) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
    }
    if (value['project_id'] != null ||
        value['scope_id'] != null ||
        !yorksV1CompanyRegisterStates.contains(value['state']) ||
        value['item_count'] is! int ||
        (value['item_count'] as int) < 0 ||
        DateTime.tryParse(value['updated_at'] as String) == null ||
        DateTime.tryParse(value['created_at'] as String) == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
  }
  final YorksV1MaterialRequest? projectRequest;
  final Map<String, dynamic>? _company;
  bool get isCompany => _company != null;
  String get id => projectRequest?.id ?? _company!['id'] as String;
  String get identity => '${isCompany ? 'company' : 'project'}:$id';
  String? get projectId => projectRequest?.projectId;
  String? get scopeId => projectRequest?.scopeId;
  String get groupKey => isCompany ? 'company' : projectId!;
  String get contextReference =>
      projectRequest?.projectReference ??
      YorksV1CompanyMaterialRequestStrings.companyUse.primary;
  String contextReferenceFor(AppLanguage language) => isCompany
      ? YorksV1CompanyMaterialRequestStrings.companyUse.active(language)
      : contextReference;
  String get contextName =>
      projectRequest?.projectName ?? _company!['category_name'] as String;
  String get scopeLabel =>
      projectRequest?.scopeName ?? _company!['responsible_unit_name'] as String;
  String get state =>
      projectRequest?.state.wireValue ?? _company!['state'] as String;
  bool get isDraft => state == 'draft';
  String? get requestNumber =>
      projectRequest?.requestNumber ?? _company?['request_number'] as String?;
  String? get title => projectRequest?.title ?? _company?['title'] as String?;
  String? get requesterDisplayName =>
      projectRequest?.requesterDisplayName ??
      _company?['requester_display_name'] as String?;
  DateTime get updatedAt =>
      projectRequest?.updatedAt ??
      DateTime.parse(_company!['updated_at'] as String);
  DateTime? get scheduledDate =>
      projectRequest?.scheduledDate ??
      DateTime.tryParse(_company?['scheduled_date'] as String? ?? '');
  int get displayItemCount =>
      projectRequest?.displayItemCount ?? _company!['item_count'] as int;
  Iterable<String> get descriptions =>
      projectRequest?.lines.map((line) => line.description) ?? const [];
  String? get currentActionOwnerRole =>
      projectRequest?.currentActionOwnerRole ??
      _company?['current_action_owner_role'] as String?;
  String? get currentActionCode =>
      projectRequest?.currentActionCode ??
      _company?['current_action_code'] as String?;
  double get currentActionAgeHours =>
      projectRequest?.currentActionAgeHours ??
      (_company?['current_action_age_hours'] as num?)?.toDouble() ??
      0;
  bool get requiredOnSiteOverdue =>
      projectRequest?.requiredOnSiteOverdue ??
      _company?['required_on_site_overdue'] == true;
  List<YorksV1MaterialRequestExceptionCode> get exceptionCodes =>
      projectRequest?.exceptionCodes ??
      ((_company?['exception_codes'] as List?) ?? const [])
          .map(YorksV1MaterialRequestExceptionCode.fromWireValue)
          .whereType<YorksV1MaterialRequestExceptionCode>()
          .toList(growable: false);
  TranslatableString get ownerCopy => switch (currentActionOwnerRole) {
    'company_approver' => YorksV1CompanyMaterialRequestStrings.companyApprover,
    'authorized_receiver' =>
      YorksV1CompanyMaterialRequestStrings.authorizedReceiver,
    'beneficiary' => YorksV1CompanyMaterialRequestStrings.beneficiary,
    'requester' => YorksV1CompanyMaterialRequestStrings.requesterOwner,
    _ => yorksV1MaterialRequestOwnerRoleCopy(currentActionOwnerRole),
  };
  TranslatableString get stateCopy => yorksV1MaterialRegisterStateCopy(state);
  TranslatableString get nextActionCopy => projectRequest != null
      ? yorksV1MaterialRequestNextActionCopy(projectRequest!)
      : switch (currentActionCode) {
          'approve' => YorksV1CompanyMaterialRequestStrings.reviewAndDecide,
          'arrange' => YorksV1CompanyMaterialRequestStrings.arrangeSupply,
          'dispatch' => YorksV1CompanyMaterialRequestStrings.dispatch,
          'receive' => YorksV1CompanyMaterialRequestStrings.confirmReceipt,
          'handover' => YorksV1CompanyMaterialRequestStrings.confirmHandover,
          'close' => YorksV1CompanyMaterialRequestStrings.closeRequest,
          'revise' => YorksV1CompanyMaterialRequestStrings.reviseAndResubmit,
          _ => stateCopy,
        };
}

const yorksV1CompanyRegisterStates = <String>{
  'draft',
  'submitted_pending_approval',
  'awaiting_company_approval',
  'returned_for_changes',
  'rejected',
  'approved_for_procurement',
  'arranging',
  'ready_for_delivery',
  'partially_dispatched',
  'receipt_pending',
  'partially_received',
  'awaiting_beneficiary_handover',
  'fulfilled',
  'closed',
  'cancelled',
};

TranslatableString yorksV1MaterialRegisterStateCopy(String state) {
  final project = YorksV1MaterialRequestState.fromWireValue(state);
  if (project != null) return yorksV1MaterialRequestStateCopy(project);
  return switch (state) {
    'submitted_pending_approval' || 'awaiting_company_approval' =>
      YorksV1CompanyMaterialRequestStrings.awaitingApproval,
    'returned_for_changes' =>
      YorksV1CompanyMaterialRequestStrings.returnedForChanges,
    'rejected' => YorksV1CompanyMaterialRequestStrings.rejected,
    'approved_for_procurement' =>
      YorksV1CompanyMaterialRequestStrings.approvedForProcurement,
    'ready_for_delivery' =>
      YorksV1CompanyMaterialRequestStrings.readyForDelivery,
    'receipt_pending' => YorksV1CompanyMaterialRequestStrings.receiptPending,
    'awaiting_beneficiary_handover' =>
      YorksV1CompanyMaterialRequestStrings.awaitingHandover,
    'fulfilled' => YorksV1CompanyMaterialRequestStrings.fulfilled,
    _ => throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    ),
  };
}

class YorksV1MaterialRegisterQuery {
  const YorksV1MaterialRegisterQuery(
    this.filters, {
    this.nativeState,
    this.requestKind,
  });
  final YorksV1MaterialRequestSummaryQuery filters;
  final String? nativeState;
  final String? requestKind;
  int get offset => filters.offset;
  YorksV1MaterialRegisterQuery copyWith({int? offset}) =>
      YorksV1MaterialRegisterQuery(
        filters.copyWith(offset: offset),
        nativeState: nativeState,
        requestKind: requestKind,
      );
  Map<String, Object?> toRpcParameters() => {
    ...filters.toRpcParameters(),
    'p_request_kind': requestKind ?? 'all',
    if (nativeState != null) 'p_states': [nativeState],
  };
  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialRegisterQuery &&
      other.filters == filters &&
      other.nativeState == nativeState &&
      other.requestKind == requestKind;
  @override
  int get hashCode => Object.hash(filters, nativeState, requestKind);
}

class YorksV1MaterialRegisterPage {
  YorksV1MaterialRegisterPage({
    required List<YorksV1MaterialRegisterEntry> items,
    required this.totalCount,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.metrics,
  }) : items = List.unmodifiable(items);
  final List<YorksV1MaterialRegisterEntry> items;
  final int totalCount;
  final int limit;
  final int offset;
  final bool hasMore;
  final YorksV1MaterialRequestSummaryMetrics metrics;
  factory YorksV1MaterialRegisterPage.project(
    YorksV1MaterialRequestSummaryPage page,
  ) => YorksV1MaterialRegisterPage(
    items: page.items
        .map(
          (entry) => YorksV1MaterialRegisterEntry.project(
            entry.toRegisterProjection(),
          ),
        )
        .toList(),
    totalCount: page.totalCount,
    limit: page.limit,
    offset: page.offset,
    hasMore: page.hasMore,
    metrics: page.metrics,
  );
  factory YorksV1MaterialRegisterPage.fromRpcJson(Map<String, dynamic> value) {
    if (value['items'] is! List ||
        value['metrics'] is! Map ||
        value['total_count'] is! int ||
        value['limit'] is! int ||
        value['offset'] is! int ||
        value['has_more'] is! bool) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1MaterialRegisterPage(
      items: (value['items'] as List).map((item) {
        if (item is! Map) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          );
        }
        final json = Map<String, dynamic>.from(item);
        return switch (json['request_kind']) {
          'project' => YorksV1MaterialRegisterEntry.project(
            YorksV1MaterialRequestSummary.fromRpcJson(
              json,
            ).toRegisterProjection(),
          ),
          'company' => YorksV1MaterialRegisterEntry.company(json),
          _ => throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          ),
        };
      }).toList(),
      totalCount: value['total_count'] as int,
      limit: value['limit'] as int,
      offset: value['offset'] as int,
      hasMore: value['has_more'] as bool,
      metrics: YorksV1MaterialRequestSummaryMetrics.fromRpcJson(
        Map<String, dynamic>.from(value['metrics'] as Map),
      ),
    );
  }
}

abstract final class YorksV1MaterialRegisterStrings {
  static const projectInsights = TranslatableString(
    en: 'Project request insights',
    ar: 'إحصاءات طلبات المشاريع',
    ur: 'پروجیکٹ درخواستوں کے اعداد و شمار',
    hi: 'परियोजना अनुरोध की जानकारी',
  );
  static const description = TranslatableString(
    en: 'Track Project and Company material requests in one place.',
    ar: 'تابع طلبات مواد المشاريع والشركة في مكان واحد.',
    ur: 'پروجیکٹ اور کمپنی کے مٹیریل درخواستوں کو ایک جگہ دیکھیں۔',
    hi: 'परियोजना और कंपनी सामग्री अनुरोध एक ही जगह देखें।',
  );
}
