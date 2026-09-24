import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_arrangement.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/repositories/yorks_v1_company_material_request_repository.dart';
import '../widgets/yorks_v1_request_use_switch.dart';
import '../widgets/yorks_v1_company_request_evidence.dart';
import 'yorks_v1_company_material_request_operations.dart';

class YorksV1CompanyMaterialRequestApprovalInboxScreen
    extends ConsumerStatefulWidget {
  const YorksV1CompanyMaterialRequestApprovalInboxScreen({super.key});

  @override
  ConsumerState<YorksV1CompanyMaterialRequestApprovalInboxScreen>
  createState() => _CompanyInboxState();
}

class _CompanyInboxState
    extends ConsumerState<YorksV1CompanyMaterialRequestApprovalInboxScreen> {
  YorksV1CompanyMaterialRequestRegisterView? _view =
      YorksV1CompanyMaterialRequestRegisterView.requests;
  Future<YorksV1CompanyMaterialRequestPage>? _register;
  Timer? _searchTimer;
  int _offset = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _load() {
    final repository = ref.read(
      yorksV1CompanyMaterialRequestRepositoryProvider,
    );
    if (repository is YorksV1CompanyMaterialRequestPagedRepository) {
      _register = (repository as YorksV1CompanyMaterialRequestPagedRepository)
          .listPage(
            view: _view?.wireValue ?? 'my_work',
            query: _query,
            offset: _offset,
          );
    } else {
      _register =
          (_view == null
                  ? repository.listApprovalInbox()
                  : repository.listRegister(_view!, limit: 200))
              .then((items) {
                final matches = items
                    .where(
                      (item) => [
                        item.requestNumber,
                        item.purpose,
                        item.requesterDisplayName,
                        item.beneficiaryDisplayName,
                        item.responsibleUnitName,
                      ].join(' ').toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();
                return YorksV1CompanyMaterialRequestPage(
                  items: matches.skip(_offset).take(15).toList(),
                  totalCount: matches.length,
                );
              });
    }
  }

  void _select(YorksV1CompanyMaterialRequestRegisterView? view) => setState(() {
    _view = view;
    _offset = 0;
    _load();
  });

  void _refresh() {
    ref.invalidate(yorksV1CompanyMaterialRequestDraftOptionsProvider);
    _select(_view);
  }

  void _search(String value) {
    _searchTimer?.cancel();
    _query = value.trim();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _select(_view);
    });
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _select(_view);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    ref.listen(yorksV1AuthUserIdProvider, (_, _) => _select(_view));
    ref.listen(
      yorksV1CompanyMaterialRequestRepositoryProvider,
      (_, _) => _select(_view),
    );
    ref.listen(
      yorksV1MaterialRequestRealtimeRevisionProvider,
      (_, _) => _select(_view),
    );
    final options = ref.watch(
      yorksV1CompanyMaterialRequestDraftOptionsProvider,
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          YorksV1RequestUseSwitch(company: true, language: language),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    YorksV1CompanyMaterialRequestStrings.approvals.active(
                      language,
                    ),
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: YorksV1CompanyMaterialRequestStrings.retry.active(
                    language,
                  ),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (options.valueOrNull?.isNotEmpty == true &&
                    MediaQuery.sizeOf(context).width < 600)
                  IconButton.filled(
                    key: const ValueKey('company-request-new-from-inbox'),
                    tooltip: YorksV1MaterialRequestStrings.newRequest.active(
                      language,
                    ),
                    onPressed: () =>
                        _open('/yorks/material-requests/company/new'),
                    icon: const Icon(Icons.add_rounded),
                  ),
                if (options.valueOrNull?.isNotEmpty == true &&
                    MediaQuery.sizeOf(context).width >= 600)
                  FilledButton.icon(
                    key: const ValueKey('company-request-new-from-inbox'),
                    onPressed: () =>
                        _open('/yorks/material-requests/company/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      YorksV1MaterialRequestStrings.newRequest.active(language),
                    ),
                  ),
              ],
            ),
          ),
          if (options.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    YorksV1CompanyMaterialRequestStrings.requestOptionsFailed
                        .active(language),
                  ),
                  TextButton(
                    key: const ValueKey('company-request-options-retry'),
                    onPressed: _refresh,
                    child: Text(
                      YorksV1CompanyMaterialRequestStrings.retry.active(
                        language,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('company-register-search'),
              onChanged: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: YorksV1CompanyMaterialRequestStrings.searchRequests
                    .active(language),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (final view in <YorksV1CompanyMaterialRequestRegisterView?>[
                  YorksV1CompanyMaterialRequestRegisterView.requests,
                  null,
                  if (ref.watch(yorksV1CurrentRoleProvider) ==
                      YorksV1Role.procurement)
                    YorksV1CompanyMaterialRequestRegisterView.planning,
                  YorksV1CompanyMaterialRequestRegisterView.issueHistory,
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: ValueKey(
                        view == null
                            ? 'company-register-my-work'
                            : 'company-register-${view.wireValue}',
                      ),
                      selected: _view == view,
                      onSelected: (_) => _select(view),
                      label: Text(
                        view == null
                            ? YorksV1CompanyMaterialRequestStrings.myWork
                                  .active(language)
                            : _registerLabel(view, language),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<YorksV1CompanyMaterialRequestPage>(
              key: ValueKey((
                _view,
                ref.watch(yorksV1AuthUserIdProvider),
                _query,
                _offset,
              )),
              future: _register,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.cloud_off_outlined,
                    message: YorksV1CompanyMaterialRequestStrings.decisionFailed
                        .active(language),
                    action: YorksV1CompanyMaterialRequestStrings.retry.active(
                      language,
                    ),
                    onPressed: () => _select(_view),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final page = snapshot.data!;
                final items = page.items;
                if (items.isEmpty) {
                  return _Message(
                    icon: Icons.task_alt_rounded,
                    message: YorksV1CompanyMaterialRequestStrings
                        .noRegisterItems
                        .active(language),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _select(_view);
                    await _register;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${_offset + 1}–${_offset + items.length} / ${page.totalCount}',
                              style: AppTypography.bodySmall,
                            ),
                            IconButton(
                              tooltip: YorksV1MaterialRequestStrings.back
                                  .active(language),
                              onPressed: _offset == 0
                                  ? null
                                  : () => setState(() {
                                      _offset -= 15;
                                      _load();
                                    }),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: YorksV1MaterialRequestStrings
                                  .continueAction
                                  .active(language),
                              onPressed:
                                  _offset + items.length >= page.totalCount
                                  ? null
                                  : () => setState(() {
                                      _offset += 15;
                                      _load();
                                    }),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        );
                      }
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InboxCard(
                          item: item,
                          language: language,
                          onOpen: () => _open(
                            item.state == 'draft'
                                ? '/yorks/material-requests/company/new?draft=${Uri.encodeComponent(item.id)}'
                                : '/yorks/material-requests/company/${item.id}',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _registerLabel(
  YorksV1CompanyMaterialRequestRegisterView view,
  AppLanguage language,
) => switch (view) {
  YorksV1CompanyMaterialRequestRegisterView.requests =>
    YorksV1CompanyMaterialRequestStrings.requests.active(language),
  YorksV1CompanyMaterialRequestRegisterView.planning =>
    YorksV1CompanyMaterialRequestStrings.planning.active(language),
  YorksV1CompanyMaterialRequestRegisterView.issueHistory =>
    YorksV1CompanyMaterialRequestStrings.issueHistory.active(language),
};

class YorksV1CompanyMaterialRequestApprovalScreen
    extends ConsumerStatefulWidget {
  const YorksV1CompanyMaterialRequestApprovalScreen({
    required this.requestId,
    super.key,
  });

  final String requestId;

  @override
  ConsumerState<YorksV1CompanyMaterialRequestApprovalScreen> createState() =>
      _ApprovalScreenState();
}

class _ApprovalScreenState
    extends ConsumerState<YorksV1CompanyMaterialRequestApprovalScreen> {
  bool _submitting = false;
  String? _decisionSignature;
  String? _idempotencyKey;

  Future<void> _decide(
    YorksV1CompanyMaterialRequest request,
    AppLanguage language,
    YorksV1CompanyMaterialRequestDecisionType type,
  ) async {
    final reason = await _decisionDialog(type, language);
    if (reason == null || !mounted) return;
    final signature =
        '${request.recordVersion}:${type.wireValue}:${reason.value ?? ''}';
    if (_decisionSignature != signature) {
      _decisionSignature = signature;
      _idempotencyKey = const Uuid().v4();
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .decide(
            requestId: request.id,
            expectedVersion: request.recordVersion,
            decision: type,
            idempotencyKey: _idempotencyKey!,
            reason: reason.value,
          );
      if (!mounted) return;
      ref.invalidate(yorksV1CompanyMaterialRequestApprovalInboxProvider);
      ref.invalidate(yorksV1CompanyMaterialRequestProvider(request.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            YorksV1CompanyMaterialRequestStrings.decisionRecorded.active(
              language,
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            YorksV1CompanyMaterialRequestStrings.decisionFailed.active(
              language,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<_Reason?> _decisionDialog(
    YorksV1CompanyMaterialRequestDecisionType type,
    AppLanguage language,
  ) async {
    if (type == YorksV1CompanyMaterialRequestDecisionType.approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            YorksV1CompanyMaterialRequestStrings.approveConfirmTitle.active(
              language,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                YorksV1MaterialRequestStrings.cancel.active(language),
              ),
            ),
            FilledButton(
              key: const ValueKey('company-approval-confirm-approve'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                YorksV1CompanyMaterialRequestStrings.approve.active(language),
              ),
            ),
          ],
        ),
      );
      return confirmed == true ? const _Reason() : null;
    }
    final controller = TextEditingController();
    final result = await showDialog<_Reason>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(_decisionLabel(type, language)),
          content: TextField(
            key: const ValueKey('company-approval-reason'),
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) => refresh(() {}),
            decoration: InputDecoration(
              labelText: YorksV1CompanyMaterialRequestStrings.decisionReason
                  .active(language),
              hintText: YorksV1CompanyMaterialRequestStrings.decisionReasonHint
                  .active(language),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                YorksV1MaterialRequestStrings.cancel.active(language),
              ),
            ),
            FilledButton(
              key: const ValueKey('company-approval-confirm-reasoned'),
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      _Reason(controller.text.trim()),
                    ),
              child: Text(_decisionLabel(type, language)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final request = ref.watch(
      yorksV1CompanyMaterialRequestProvider(widget.requestId),
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.reviewRequest.active(language),
        ),
      ),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          icon: Icons.cloud_off_outlined,
          message: YorksV1CompanyMaterialRequestStrings.decisionFailed.active(
            language,
          ),
          action: YorksV1CompanyMaterialRequestStrings.retry.active(language),
          onPressed: () => ref.invalidate(
            yorksV1CompanyMaterialRequestProvider(widget.requestId),
          ),
        ),
        data: (value) => _ApprovalDetail(
          request: value,
          language: language,
          submitting: _submitting,
          onDecide: (type) => _decide(value, language, type),
        ),
      ),
    );
  }
}

class _Reason {
  const _Reason([this.value]);
  final String? value;
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.item,
    required this.language,
    required this.onOpen,
  });
  final YorksV1CompanyMaterialRequestApprovalInboxItem item;
  final AppLanguage language;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('company-approval-${item.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.business_center_outlined, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.requestNumber.isEmpty
                            ? YorksV1CompanyMaterialRequestStrings.privateDraft
                                  .active(language)
                            : item.requestNumber,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.blue,
                        ),
                      ),
                      Text(
                        _stateLabel(item.state, language),
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.purpose,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.responsibleUnitName} · ${YorksV1CompanyMaterialRequestStrings.itemCount(item.lineCount).active(language)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.state == 'draft'
                        ? YorksV1CompanyMaterialRequestStrings.resumeDraft
                              .active(language)
                        : '${_currentOwner(item.state, language)} · ${_nextAction(item.state, language)}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _CompanyLifecycleProgress extends StatelessWidget {
  const _CompanyLifecycleProgress({
    required this.state,
    required this.language,
  });

  final String state;
  final AppLanguage language;

  int get _activeIndex => switch (state) {
    'submitted_pending_approval' ||
    'awaiting_company_approval' ||
    'returned_for_changes' ||
    'rejected' => 1,
    'approved_for_procurement' || 'arranging' => 2,
    'ready_for_delivery' => 3,
    'partially_dispatched' || 'receipt_pending' => 4,
    'partially_received' || 'awaiting_beneficiary_handover' => 5,
    'fulfilled' || 'closed' => 6,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final labels = [
      YorksV1CompanyMaterialRequestStrings.requests.active(language),
      YorksV1CompanyMaterialRequestStrings.awaitingApproval.active(language),
      YorksV1CompanyMaterialRequestStrings.planning.active(language),
      YorksV1CompanyMaterialRequestStrings.readyForDelivery.active(language),
      YorksV1CompanyMaterialRequestStrings.dispatch.active(language),
      YorksV1CompanyMaterialRequestStrings.awaitingHandover.active(language),
      YorksV1CompanyMaterialRequestStrings.closed.active(language),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const ValueKey('company-request-progress'),
        title: Text(
          YorksV1CompanyMaterialRequestStrings.flowDetails.active(language),
        ),
        subtitle: Text(_stateLabel(state, language)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < labels.length; index++)
                Chip(
                  avatar: Icon(
                    index < _activeIndex
                        ? Icons.check_circle_rounded
                        : index == _activeIndex
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: index <= _activeIndex
                        ? AppColors.blue
                        : AppColors.muted,
                  ),
                  label: Text(labels[index]),
                  backgroundColor: index == _activeIndex
                      ? AppColors.blueContainer
                      : AppColors.surfaceContainerLow,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalDetail extends StatelessWidget {
  const _ApprovalDetail({
    required this.request,
    required this.language,
    required this.submitting,
    required this.onDecide,
  });
  final YorksV1CompanyMaterialRequest request;
  final AppLanguage language;
  final bool submitting;
  final ValueChanged<YorksV1CompanyMaterialRequestDecisionType> onDecide;

  String get _next => request.canReceive && request.pendingDispatches.isNotEmpty
      ? YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(language)
      : request.canHandover && request.unallocatedReceiptLines.isNotEmpty
      ? YorksV1CompanyMaterialRequestStrings.confirmHandover.active(language)
      : _nextAction(request.state, language);

  String get _owner =>
      request.canReceive && request.pendingDispatches.isNotEmpty
      ? request.authorizedReceiver.displayName
      : request.canHandover && request.unallocatedReceiptLines.isNotEmpty
      ? request.beneficiary.displayName
      : switch (request.state) {
          'submitted_pending_approval' || 'awaiting_company_approval' =>
            request.approver?.displayName ??
                _currentOwner(request.state, language),
          'returned_for_changes' || 'draft' => request.requesterDisplayName,
          'receipt_pending' ||
          'partially_dispatched' => request.authorizedReceiver.displayName,
          'awaiting_beneficiary_handover' => request.beneficiary.displayName,
          _ => _currentOwner(request.state, language),
        };

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    request.requestNumber ??
                        YorksV1CompanyMaterialRequestStrings.privateDraft
                            .active(language),
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(
                      Icons.business_center_outlined,
                      size: 16,
                    ),
                    label: Text(
                      YorksV1CompanyMaterialRequestStrings.companyUse.active(
                        language,
                      ),
                    ),
                  ),
                  Text(
                    _stateLabel(request.state, language),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.purpose,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${request.responsibleUnitName} · ${request.deliveryCollectionPoint}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _next,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${YorksV1CompanyMaterialRequestStrings.currentOwner.active(language)}: $_owner',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                      if (request.canDecide) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('company-approval-approve'),
                              onPressed: submitting
                                  ? null
                                  : () => onDecide(
                                      YorksV1CompanyMaterialRequestDecisionType
                                          .approved,
                                    ),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                YorksV1CompanyMaterialRequestStrings.approve
                                    .active(language),
                              ),
                            ),
                            OutlinedButton(
                              key: const ValueKey('company-approval-return'),
                              onPressed: submitting
                                  ? null
                                  : () => onDecide(
                                      YorksV1CompanyMaterialRequestDecisionType
                                          .returned,
                                    ),
                              child: Text(
                                YorksV1CompanyMaterialRequestStrings
                                    .returnForChanges
                                    .active(language),
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('company-approval-reject'),
                              onPressed: submitting
                                  ? null
                                  : () => onDecide(
                                      YorksV1CompanyMaterialRequestDecisionType
                                          .rejected,
                                    ),
                              child: Text(
                                YorksV1CompanyMaterialRequestStrings.reject
                                    .active(language),
                              ),
                            ),
                          ],
                        ),
                      ],
                      _FulfilmentActions(request: request, language: language),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        YorksV1CompanyMaterialRequestStrings.materialItems
                            .active(language),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final line in request.lines) ...[
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${line.displayOrder}',
                                style: AppTypography.labelLarge,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.description,
                                    style: AppTypography.titleSmall,
                                  ),
                                  if ([
                                    line.size,
                                    line.model,
                                    line.equipmentTag,
                                    line.brandOrigin,
                                  ].any((v) => v?.isNotEmpty == true))
                                    Text(
                                      [
                                            line.size,
                                            line.model,
                                            line.equipmentTag,
                                            line.brandOrigin,
                                          ]
                                          .whereType<String>()
                                          .where((v) => v.isNotEmpty)
                                          .join(' · '),
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${line.quantity} ${line.unit}',
                              style: AppTypography.labelLarge,
                            ),
                          ],
                        ),
                        if (request.currentSupplyPlan != null ||
                            request.decisions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 32,
                              top: 6,
                            ),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '${YorksV1CompanyMaterialRequestStrings.received.active(language)}: ${line.goodReceivedQuantity}',
                                  style: AppTypography.bodySmall,
                                ),
                                if ((double.tryParse(line.handedOverQuantity) ??
                                        0) >
                                    0)
                                  Text(
                                    '${YorksV1CompanyMaterialRequestStrings.handedOver.active(language)}: ${line.handedOverQuantity}',
                                    style: AppTypography.bodySmall,
                                  ),
                                if ((double.tryParse(line.withdrawnQuantity) ??
                                        0) >
                                    0)
                                  Text(
                                    '${YorksV1CompanyMaterialRequestStrings.withdrawn.active(language)}: ${line.withdrawnQuantity}',
                                    style: AppTypography.bodySmall,
                                  ),
                                if ((double.tryParse(line.returnedQuantity) ??
                                        0) >
                                    0)
                                  Text(
                                    '${YorksV1CompanyMaterialRequestStrings.returned.active(language)}: ${line.returnedQuantity}',
                                    style: AppTypography.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (request.state != 'cancelled') ...[
                _CompanyLifecycleProgress(
                  state: request.state,
                  language: language,
                ),
                const SizedBox(height: 12),
              ],
              YorksV1CompanyRequestEvidence(
                requestId: request.id,
                recordVersion: request.recordVersion,
                language: language,
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const ValueKey('company-request-information'),
                  title: Text(
                    YorksV1CompanyMaterialRequestStrings.showRequestInformation
                        .active(language),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    _Fact(
                      label: YorksV1CompanyMaterialRequestStrings.requestedBy
                          .active(language),
                      value: request.requesterDisplayName,
                    ),
                    _Fact(
                      label: YorksV1CompanyMaterialRequestStrings.beneficiary
                          .active(language),
                      value: request.beneficiary.displayName,
                    ),
                    _Fact(
                      label: YorksV1CompanyMaterialRequestStrings
                          .authorizedReceiver
                          .active(language),
                      value: request.authorizedReceiver.displayName,
                    ),
                    if (request.approver != null)
                      _Fact(
                        label: YorksV1CompanyMaterialRequestStrings.approver
                            .active(language),
                        value: request.approver!.displayName,
                      ),
                  ],
                ),
              ),
              if (request.decisions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    title: Text(
                      YorksV1CompanyMaterialRequestStrings.decisionHistory
                          .active(language),
                    ),
                    children: [
                      for (final decision in request.decisions)
                        ListTile(
                          title: Text(
                            _decisionWireLabel(decision.decision, language),
                          ),
                          subtitle: Text(
                            [
                              decision.decidedByDisplayName,
                              decision.decidedByExactRole,
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(decision.decidedAt.toLocal()),
                              if (decision.reason != null) decision.reason!,
                            ].join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _FulfilmentActions extends ConsumerStatefulWidget {
  const _FulfilmentActions({required this.request, required this.language});

  final YorksV1CompanyMaterialRequest request;
  final AppLanguage language;

  @override
  ConsumerState<_FulfilmentActions> createState() => _FulfilmentActionsState();
}

class _FulfilmentActionsState extends ConsumerState<_FulfilmentActions> {
  bool _busy = false;
  final Map<String, String> _commandKeys = {};
  String _commandKey(String operation, Object payload) =>
      _commandKeys.putIfAbsent(
        '$operation:${widget.request.recordVersion}:${jsonEncode(payload)}',
        () => const Uuid().v4(),
      );

  Future<void> _reviseAndResubmit() async {
    final formKey = GlobalKey<FormState>();
    final reason = TextEditingController();
    final descriptions = {
      for (final line in widget.request.lines)
        line.id: TextEditingController(text: line.description),
    };
    final purpose = TextEditingController(text: widget.request.purpose);
    final delivery = TextEditingController(
      text: widget.request.deliveryCollectionPoint,
    );
    final quantities = {
      for (final line in widget.request.lines)
        line.id: TextEditingController(text: line.quantity),
    };
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(
            widget.language,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: purpose,
                  validator: (v) => v?.trim().isNotEmpty == true
                      ? null
                      : YorksV1CompanyMaterialRequestStrings.changeReason
                            .active(widget.language),
                  decoration: InputDecoration(
                    labelText: YorksV1CompanyMaterialRequestStrings.purpose
                        .active(widget.language),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: delivery,
                  validator: (v) => v?.trim().isNotEmpty == true
                      ? null
                      : YorksV1CompanyMaterialRequestStrings
                            .deliveryCollectionPoint
                            .active(widget.language),
                  decoration: InputDecoration(
                    labelText: YorksV1CompanyMaterialRequestStrings
                        .deliveryCollectionPoint
                        .active(widget.language),
                  ),
                ),
                Text(
                  YorksV1CompanyMaterialRequestStrings.correctionNotice.active(
                    widget.language,
                  ),
                ),
                TextFormField(
                  key: const ValueKey("company-change-reason"),
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: YorksV1CompanyMaterialRequestStrings.changeReason
                        .active(widget.language),
                  ),
                  validator: (v) => v?.trim().isNotEmpty == true
                      ? null
                      : YorksV1CompanyMaterialRequestStrings.changeReason
                            .active(widget.language),
                ),
                for (final line in widget.request.lines) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptions[line.id],
                    decoration: InputDecoration(
                      labelText: YorksV1CompanyMaterialRequestStrings
                          .itemDescription
                          .active(widget.language),
                    ),
                    validator: (v) => v?.trim().isNotEmpty == true
                        ? null
                        : YorksV1CompanyMaterialRequestStrings.itemDescription
                              .active(widget.language),
                  ),
                  TextFormField(
                    controller: quantities[line.id],
                    validator: (v) {
                      final q = double.tryParse(v?.trim() ?? '');
                      return q != null && q.isFinite && q > 0
                          ? null
                          : YorksV1CompanyMaterialRequestStrings.quantityLimit
                                .active(widget.language);
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${line.description} · ${YorksV1CompanyMaterialRequestStrings.quantity.active(widget.language)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              YorksV1MaterialRequestStrings.cancel.active(widget.language),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(
              YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    );
    final confirmed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialog);
    await dialog.completed;
    if (confirmed == true && mounted) {
      await _run(
        () => ref
            .read(yorksV1CompanyMaterialRequestRepositoryProvider)
            .reviseAndResubmit(
              requestId: widget.request.id,
              expectedVersion: widget.request.recordVersion,
              purpose: purpose.text.trim(),
              reason: reason.text.trim(),
              deliveryCollectionPoint: delivery.text.trim(),
              lines: [
                for (final line in widget.request.lines)
                  {
                    'id': line.id,
                    'item_description': descriptions[line.id]!.text.trim(),
                    'brand_origin': line.brandOrigin,
                    'requested_qty': quantities[line.id]!.text.trim(),
                    'unit': line.unit,
                  },
              ],
              idempotencyKey: _commandKey('revise', [
                reason.text.trim(),
                for (final line in widget.request.lines)
                  descriptions[line.id]!.text.trim(),
                purpose.text.trim(),
                delivery.text.trim(),
                for (final line in widget.request.lines)
                  quantities[line.id]!.text.trim(),
              ]),
            ),
      );
    }
    reason.dispose();
    for (final controller in descriptions.values) {
      controller.dispose();
    }
    purpose.dispose();
    delivery.dispose();
    for (final controller in quantities.values) {
      controller.dispose();
    }
  }

  Future<void> _cancelRequest() async {
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.cancelRequest.active(
            widget.language,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey("company-change-reason"),
            controller: reason,
            autofocus: true,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: YorksV1CompanyMaterialRequestStrings.changeReason
                  .active(widget.language),
            ),
            validator: (v) => v?.trim().isNotEmpty == true
                ? null
                : YorksV1CompanyMaterialRequestStrings.changeReason.active(
                    widget.language,
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              YorksV1MaterialRequestStrings.back.active(widget.language),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(
              YorksV1CompanyMaterialRequestStrings.cancelRequest.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    );
    final confirmed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialog);
    await dialog.completed;
    final explanation = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .cancel(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            reason: explanation,
            idempotencyKey: _commandKey('cancel', explanation),
          ),
    );
  }

  Future<void> _run(
    Future<YorksV1CompanyMaterialRequest> Function() command,
  ) async {
    setState(() => _busy = true);
    try {
      await command();
      if (!mounted) return;
      ref.invalidate(yorksV1CompanyMaterialRequestProvider(widget.request.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            YorksV1CompanyMaterialRequestStrings.actionRecorded.active(
              widget.language,
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            YorksV1CompanyMaterialRequestStrings.actionFailed.active(
              widget.language,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _plan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final inventory = await ref.read(
        yorksV1ArrangementInventoryProvider.future,
      );
      if (!mounted) return;
      final outstanding = widget.request.lines
          .where(
            (line) => (double.tryParse(line.withdrawableQuantity) ?? 0) > 0,
          )
          .toList();
      final choices = await showDialog<List<CompanySupplyPlanChoice>>(
        context: context,
        builder: (_) => CompanyLineReview<CompanySupplyPlanChoice>(
          title: YorksV1CompanyMaterialRequestStrings.arrangeItems.active(
            widget.language,
          ),
          descriptions: [
            for (final line in outstanding)
              '${line.description} · ${line.withdrawableQuantity} ${line.unit}',
          ],
          language: widget.language,
          confirmLabel: YorksV1CompanyMaterialRequestStrings.saveSupplyPlan
              .active(widget.language),
          summary: (choice) =>
              '${choice.quantity} · ${choice.decision == 'full'
                  ? YorksV1CompanyMaterialRequestStrings.full.active(widget.language)
                  : choice.decision == 'partial'
                  ? YorksV1CompanyMaterialRequestStrings.partial.active(widget.language)
                  : YorksV1CompanyMaterialRequestStrings.cannotProvideNow.active(widget.language)}',
          edit: (index, previous) => showDialog<CompanySupplyPlanChoice>(
            context: context,
            builder: (_) => CompanySupplyPlanDialog(
              line: outstanding[index],
              outstandingQuantity: outstanding[index].withdrawableQuantity,
              inventory: inventory
                  .where(
                    (item) =>
                        item.unit.toLowerCase() ==
                        outstanding[index].unit.toLowerCase(),
                  )
                  .toList(),
              language: widget.language,
              initial: previous,
            ),
          ),
        ),
      );
      if (choices == null || !mounted) return;
      final lines = [
        for (var i = 0; i < choices.length; i++)
          choices[i].toPayload(outstanding[i].id),
      ];
      await _run(
        () => ref
            .read(yorksV1CompanyMaterialRequestRepositoryProvider)
            .saveSupplyPlan(
              requestId: widget.request.id,
              expectedVersion: widget.request.recordVersion,
              lines: lines,
              idempotencyKey: _commandKey('plan', lines),
            ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1CompanyMaterialRequestStrings.actionFailed.active(
                widget.language,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dispatch() async {
    final planLines = widget.request.currentSupplyPlan?['lines'];
    if (planLines is! List) return;
    final items = <CompanyQuantityItem>[];
    for (final raw in planLines.whereType<Map>()) {
      final remaining = raw['dispatchable_qty']?.toString() ?? '0';
      final line = widget.request.lines
          .where((line) => line.id == raw['request_line_id'])
          .firstOrNull;
      if (line != null && (double.tryParse(remaining) ?? 0) > 0) {
        items.add(
          CompanyQuantityItem(
            id: raw['id'].toString(),
            description: line.description,
            unit: line.unit,
            maximum: remaining,
          ),
        );
      }
    }
    final selected = await _quantities(
      YorksV1CompanyMaterialRequestStrings.dispatch.active(widget.language),
      items,
      selectAll: true,
    );
    if (selected == null || !mounted) return;
    final lines = [
      for (final entry in selected.quantities.entries)
        {'supply_line_id': entry.key, 'dispatch_qty': entry.value},
    ];
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .dispatch(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            lines: lines,
            idempotencyKey: _commandKey('dispatch', lines),
          ),
    );
  }

  Future<void> _receive() async {
    if (widget.request.pendingDispatches.isEmpty) return;
    final dispatch = widget.request.pendingDispatches.first;
    final rawLines = dispatch['lines'];
    if (rawLines is! List) return;
    final records = rawLines.whereType<Map>().toList();
    String label(Map raw) {
      final line = widget.request.lines
          .where((line) => line.id == raw['request_line_id'])
          .firstOrNull;
      return '${line?.description ?? ''} · ${raw['dispatched_qty']} ${line?.unit ?? ''}';
    }

    final choices = await showDialog<List<_ReceiptChoice>>(
      context: context,
      builder: (_) => CompanyLineReview<_ReceiptChoice>(
        title:
            '${YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(widget.language)} · ${dispatch['dispatch_number'] ?? ''}',
        descriptions: records.map(label).toList(),
        language: widget.language,
        confirmLabel: YorksV1CompanyMaterialRequestStrings.confirmReceipt
            .active(widget.language),
        summary: (choice) =>
            '${YorksV1CompanyMaterialRequestStrings.received.active(widget.language)}: ${choice.goodQuantity}',
        edit: (index, previous) => showDialog<_ReceiptChoice>(
          context: context,
          builder: (_) => _ReceiptDialog(
            description: label(records[index]),
            dispatchedQuantity: records[index]['dispatched_qty'].toString(),
            language: widget.language,
            initial: previous,
          ),
        ),
      ),
    );
    if (choices == null || !mounted) return;
    final lines = [
      for (var i = 0; i < choices.length; i++)
        choices[i].toPayload(records[i]['id'].toString()),
    ];
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .confirmReceipt(
            requestId: widget.request.id,
            dispatchId: dispatch['id'].toString(),
            expectedVersion: widget.request.recordVersion,
            lines: lines,
            idempotencyKey: _commandKey('receipt', [dispatch['id'], lines]),
          ),
    );
  }

  Future<void> _handover() async {
    final actor = ref.read(yorksV1AuthUserIdProvider);
    if (actor == null) return;
    final beneficiaryAcknowledges =
        actor == widget.request.beneficiary.authUserId;
    final selected = await _quantities(
      YorksV1CompanyMaterialRequestStrings.confirmHandover.active(
        widget.language,
      ),
      _quantityItems(widget.request.unallocatedReceiptLines, 'available_qty'),
      selectAll: true,
      message:
          '${widget.request.beneficiary.displayName} — ${(beneficiaryAcknowledges ? YorksV1CompanyMaterialRequestStrings.handoverSelf : YorksV1CompanyMaterialRequestStrings.handoverWitness).active(widget.language)}',
    );
    if (selected == null || !mounted) return;
    final basis = beneficiaryAcknowledges
        ? 'beneficiary_confirmed'
        : 'authorized_receiver_witnessed';
    final lines = [
      for (final entry in selected.quantities.entries)
        {'receipt_line_id': entry.key, 'quantity': entry.value},
    ];
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .confirmHandover(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            acknowledgementBasis: basis,
            lines: lines,
            idempotencyKey: _commandKey('handover', [basis, lines]),
          ),
    );
  }

  Future<void> _return() async {
    final selected = await _quantities(
      YorksV1CompanyMaterialRequestStrings.submitReturn.active(widget.language),
      _quantityItems(widget.request.returnableHandoverLines, 'returnable_qty'),
      requireReason: true,
    );
    if (selected == null || !mounted) return;
    final lines = [
      for (final entry in selected.quantities.entries)
        {'handover_line_id': entry.key, 'quantity': entry.value},
    ];
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .submitReturn(
            requestId: widget.request.id,
            reason: selected.reason!,
            lines: lines,
            idempotencyKey: _commandKey('return', [selected.reason, lines]),
          ),
    );
  }

  Future<void> _withdrawRemainder() async {
    final selected = await _quantities(
      YorksV1CompanyMaterialRequestStrings.withdrawRemainder.active(
        widget.language,
      ),
      [
        for (final line in widget.request.lines)
          if ((double.tryParse(line.withdrawableQuantity) ?? 0) > 0)
            CompanyQuantityItem(
              id: line.id,
              description: line.description,
              unit: line.unit,
              maximum: line.withdrawableQuantity,
            ),
      ],
      requireReason: true,
    );
    if (selected == null || !mounted) return;
    final lines = [
      for (final entry in selected.quantities.entries)
        {'request_line_id': entry.key, 'quantity': entry.value},
    ];
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .withdrawRemainder(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            reason: selected.reason!,
            lines: lines,
            idempotencyKey: _commandKey('withdraw', [selected.reason, lines]),
          ),
    );
  }

  List<CompanyQuantityItem> _quantityItems(
    List<Map<String, dynamic>> records,
    String quantityKey,
  ) => [
    for (final raw in records)
      for (final line in widget.request.lines.where(
        (line) => line.id == raw['request_line_id'],
      ))
        CompanyQuantityItem(
          id: raw['id'].toString(),
          description: line.description,
          unit: line.unit,
          maximum: raw[quantityKey].toString(),
        ),
  ];

  Future<CompanyQuantitySelection?> _quantities(
    String title,
    List<CompanyQuantityItem> items, {
    bool requireReason = false,
    bool selectAll = false,
    String? message,
  }) async {
    if (items.isEmpty) return null;
    return showDialog<CompanyQuantitySelection>(
      context: context,
      builder: (_) => CompanyQuantityReview(
        title: title,
        items: items,
        language: widget.language,
        requireReason: requireReason,
        selectAll: selectAll,
        message: message,
      ),
    );
  }

  Future<void> _confirmReturn(String returnId) async {
    final reusable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.confirmReturn.active(
            widget.language,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              YorksV1MaterialRequestStrings.cancel.active(widget.language),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.nonReusableReturn.active(
                widget.language,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.reusableReturn.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    );
    if (reusable == null || !mounted) return;
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .decideReturn(
            returnId: returnId,
            confirm: true,
            reusable: reusable,
            reason: null,
            idempotencyKey: _commandKey('confirm-return', [returnId, reusable]),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (widget.request.canRevise) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _reviseAndResubmit,
          icon: const Icon(Icons.edit_note_rounded),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.editRequest.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canCancel) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancelRequest,
          icon: const Icon(Icons.cancel_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.cancelRequest.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canPlan) {
      final label = Text(
        YorksV1CompanyMaterialRequestStrings.arrangeItems.active(
          widget.language,
        ),
      );
      const icon = Icon(Icons.inventory_2_outlined);
      actions.add(
        widget.request.canDispatch
            ? OutlinedButton.icon(
                onPressed: _busy ? null : _plan,
                icon: icon,
                label: label,
              )
            : FilledButton.icon(
                onPressed: _busy ? null : _plan,
                icon: icon,
                label: label,
              ),
      );
    }
    if (widget.request.canDispatch) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _dispatch,
          icon: const Icon(Icons.local_shipping_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.dispatch.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canReceive &&
        widget.request.pendingDispatches.isNotEmpty) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _receive,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canHandover &&
        widget.request.unallocatedReceiptLines.isNotEmpty) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _handover,
          icon: const Icon(Icons.handshake_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.confirmHandover.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canSubmitReturn &&
        widget.request.returnableHandoverLines.isNotEmpty) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _return,
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.submitReturn.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canDecideReturns) {
      for (final pendingReturn in widget.request.pendingReturns) {
        actions.add(
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _confirmReturn(pendingReturn['id'].toString()),
            icon: const Icon(Icons.inventory_outlined),
            label: Text(
              YorksV1CompanyMaterialRequestStrings.confirmReturn.active(
                widget.language,
              ),
            ),
          ),
        );
      }
    }
    if (widget.request.canWithdrawRemainder) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _withdrawRemainder,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.withdrawRemainder.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canClose && widget.request.state == 'fulfilled') {
      actions.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref
                      .read(yorksV1CompanyMaterialRequestRepositoryProvider)
                      .close(
                        requestId: widget.request.id,
                        expectedVersion: widget.request.recordVersion,
                        idempotencyKey: _commandKey('close', widget.request.id),
                      ),
                ),
          icon: const Icon(Icons.task_alt_rounded),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.closeRequest.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: actions),
    );
  }
}

class _ReceiptChoice {
  const _ReceiptChoice({
    required this.outcome,
    required this.goodQuantity,
    required this.exceptionQuantity,
    this.note,
  });
  final String outcome;
  final String goodQuantity;
  final String exceptionQuantity;
  final String? note;

  Map<String, Object?> toPayload(String dispatchLineId) => {
    'dispatch_line_id': dispatchLineId,
    'outcome': outcome,
    'good_qty': goodQuantity,
    'exception_qty': exceptionQuantity,
    'note': note,
  };
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({
    required this.dispatchedQuantity,
    required this.language,
    required this.description,
    this.initial,
  });
  final String dispatchedQuantity;
  final AppLanguage language;
  final String description;
  final _ReceiptChoice? initial;

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  String _outcome = 'received';
  bool _invalid = false;
  final TextEditingController _good = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _outcome = widget.initial?.outcome ?? 'received';
    _good.text = widget.initial?.goodQuantity ?? widget.dispatchedQuantity;
    _note.text = widget.initial?.note ?? '';
  }

  @override
  void dispose() {
    _good.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(
        widget.language,
      ),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.description),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _outcome,
            items: [
              DropdownMenuItem(
                value: 'received',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.receivedGood.active(
                    widget.language,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'missing',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.missing.active(
                    widget.language,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'damaged',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.damaged.active(
                    widget.language,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'incorrect',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.incorrect.active(
                    widget.language,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _outcome = value!;
              if (value == 'received') {
                _good.text = widget.dispatchedQuantity;
              } else {
                _good.text = '0';
              }
            }),
          ),
          if (_outcome != 'received') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _good,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: YorksV1CompanyMaterialRequestStrings.receivedGood
                    .active(widget.language),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: YorksV1CompanyMaterialRequestStrings.receiptNote
                    .active(widget.language),
              ),
            ),
          ],
          if (_invalid)
            Text(
              YorksV1CompanyMaterialRequestStrings.checkLine.active(
                widget.language,
              ),
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          YorksV1MaterialRequestStrings.cancel.active(widget.language),
        ),
      ),
      FilledButton(
        onPressed: () {
          final dispatched = double.tryParse(widget.dispatchedQuantity) ?? 0;
          final good = double.tryParse(_good.text.trim()) ?? -1;
          final exception = dispatched - good;
          if (!good.isFinite ||
              good < 0 ||
              exception < 0 ||
              (_outcome != 'received' &&
                  (exception <= 0 || _note.text.trim().isEmpty))) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(
            context,
            _ReceiptChoice(
              outcome: _outcome,
              goodQuantity: good.toString(),
              exceptionQuantity: exception.toString(),
              note: _outcome == 'received' ? null : _note.text.trim(),
            ),
          );
        },
        child: Text(
          YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(
            widget.language,
          ),
        ),
      ),
    ],
  );
}

class CompanySupplyPlanChoice {
  const CompanySupplyPlanChoice({
    required this.decision,
    required this.quantity,
    this.inventoryItemId,
    this.externalSupplier,
    this.reason,
    this.followUpDate,
  });
  final String? followUpDate;
  final String decision;
  final String quantity;
  final String? inventoryItemId;
  final String? externalSupplier;
  final String? reason;

  Map<String, Object?> toPayload(String requestLineId) => {
    'request_line_id': requestLineId,
    'decision': decision,
    'source_kind': quantity == '0'
        ? null
        : inventoryItemId == null
        ? 'external_supplier'
        : 'warehouse',
    'inventory_item_id': inventoryItemId,
    'external_supplier': externalSupplier,
    'arranged_qty': quantity,
    'expected_available_date': null,
    'follow_up_date': followUpDate,
    'reason': reason,
  };
}

class CompanySupplyPlanDialog extends StatefulWidget {
  const CompanySupplyPlanDialog({
    super.key,
    required this.line,
    required this.outstandingQuantity,
    required this.inventory,
    required this.language,
    this.initial,
  });
  final YorksV1CompanyMaterialRequestLine line;
  final String outstandingQuantity;
  final CompanySupplyPlanChoice? initial;
  final List<YorksV1InventoryItem> inventory;
  final AppLanguage language;

  @override
  State<CompanySupplyPlanDialog> createState() =>
      CompanySupplyPlanDialogState();
}

class CompanySupplyPlanDialogState extends State<CompanySupplyPlanDialog> {
  late final TextEditingController _quantity = TextEditingController(
    text: widget.outstandingQuantity,
  );
  final TextEditingController _stockSearch = TextEditingController();
  final TextEditingController _supplier = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String _decision = 'full';
  String _source = 'warehouse';
  String? _inventoryItemId;
  DateTime? _followUp;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    final previous = widget.initial;
    _inventoryItemId = previous?.inventoryItemId;
    _decision = previous?.decision ?? 'full';
    _source = previous == null
        ? 'warehouse'
        : previous.inventoryItemId == null
        ? 'external_supplier'
        : 'warehouse';
    _quantity.text = previous?.quantity ?? widget.outstandingQuantity;
    _supplier.text = previous?.externalSupplier ?? '';
    _reason.text = previous?.reason ?? '';
    _followUp = DateTime.tryParse(previous?.followUpDate ?? '');
    final selected = widget.inventory
        .where((item) => item.id == _inventoryItemId)
        .firstOrNull;
    if (selected != null) {
      _stockSearch.text =
          '${selected.description} · ${selected.availableQuantity} ${selected.unit}';
    }
    _stockSearch.addListener(() {
      final chosen = widget.inventory
          .where((item) => item.id == _inventoryItemId)
          .firstOrNull;
      if (chosen != null &&
          _stockSearch.text !=
              '${chosen.description} · ${chosen.availableQuantity} ${chosen.unit}') {
        setState(() => _inventoryItemId = null);
      }
    });
  }

  @override
  void dispose() {
    _stockSearch.dispose();
    _quantity.dispose();
    _supplier.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.line.description),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _decision,
            items: [
              DropdownMenuItem(
                value: 'full',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.full.active(
                    widget.language,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'partial',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.partial.active(
                    widget.language,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'unavailable',
                child: Text(
                  YorksV1CompanyMaterialRequestStrings.cannotProvideNow.active(
                    widget.language,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _decision = value!;
              _quantity.text = value == 'unavailable'
                  ? '0'
                  : widget.outstandingQuantity;
            }),
          ),
          const SizedBox(height: 12),
          if (_decision != 'unavailable') ...[
            SegmentedButton<String>(
              direction: MediaQuery.sizeOf(context).width < 600
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: [
                ButtonSegment(
                  value: 'warehouse',
                  label: Text(
                    YorksV1CompanyMaterialRequestStrings.warehouseSource.active(
                      widget.language,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: 'external_supplier',
                  label: Text(
                    YorksV1CompanyMaterialRequestStrings.externalSource.active(
                      widget.language,
                    ),
                  ),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (value) =>
                  setState(() => _source = value.first),
            ),
            const SizedBox(height: 12),
            if (_source == 'warehouse')
              DropdownMenu<String>(
                key: const ValueKey('company-plan-stock-search'),
                controller: _stockSearch,
                initialSelection: _inventoryItemId,
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                enableSearch: true,
                requestFocusOnTap: true,
                menuHeight: 260,
                label: Text(
                  YorksV1CompanyMaterialRequestStrings.chooseInventory.active(
                    widget.language,
                  ),
                ),
                dropdownMenuEntries: [
                  for (final item in widget.inventory)
                    DropdownMenuEntry(
                      value: item.id,
                      label:
                          '${item.description} · ${item.availableQuantity} ${item.unit}',
                      labelWidget: Text(
                        '${item.description} · ${item.availableQuantity} ${item.unit}',
                      ),
                    ),
                ],
                onSelected: (value) => setState(() => _inventoryItemId = value),
              )
            else
              TextField(
                controller: _supplier,
                decoration: InputDecoration(
                  labelText: YorksV1CompanyMaterialRequestStrings.externalSource
                      .active(widget.language),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: YorksV1CompanyMaterialRequestStrings.quantity.active(
                  widget.language,
                ),
              ),
            ),
          ],
          if (_decision != 'full') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: YorksV1CompanyMaterialRequestStrings.reasonRequired
                    .active(widget.language),
              ),
            ),
          ],
          if (_decision == 'unavailable')
            TextButton.icon(
              onPressed: () async {
                final now = DateUtils.dateOnly(DateTime.now());
                final date = await showDatePicker(
                  context: context,
                  initialDate: _followUp != null && !_followUp!.isBefore(now)
                      ? _followUp!
                      : now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (date != null && mounted) setState(() => _followUp = date);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _followUp == null
                    ? YorksV1CompanyMaterialRequestStrings.followUpDate.active(
                        widget.language,
                      )
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(_followUp!),
              ),
            ),
          if (_invalid)
            Text(
              YorksV1CompanyMaterialRequestStrings.checkLine.active(
                widget.language,
              ),
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('company-plan-cancel'),
        onPressed: () => Navigator.pop(context),
        child: Text(
          YorksV1MaterialRequestStrings.cancel.active(widget.language),
        ),
      ),
      FilledButton(
        key: const ValueKey('company-plan-save'),
        onPressed: () {
          final quantity = _decision == 'unavailable'
              ? 0.0
              : double.tryParse(_quantity.text.trim());
          final maximum = double.tryParse(widget.outstandingQuantity) ?? 0;
          final invalid =
              quantity == null ||
              !quantity.isFinite ||
              quantity < 0 ||
              quantity > maximum ||
              (_decision == 'full' && quantity != maximum) ||
              (_decision == 'partial' &&
                  (quantity <= 0 || quantity >= maximum)) ||
              (_decision != 'full' && _reason.text.trim().isEmpty) ||
              (_decision == 'unavailable' &&
                  (_followUp == null ||
                      _followUp!.isBefore(
                        DateUtils.dateOnly(DateTime.now()),
                      ))) ||
              (_decision != 'unavailable' &&
                  (_source == 'warehouse'
                      ? _inventoryItemId == null
                      : _supplier.text.trim().isEmpty));
          if (invalid) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(
            context,
            CompanySupplyPlanChoice(
              decision: _decision,
              quantity: _decision == 'unavailable'
                  ? '0'
                  : _quantity.text.trim(),
              inventoryItemId:
                  _decision != 'unavailable' && _source == 'warehouse'
                  ? _inventoryItemId
                  : null,
              externalSupplier:
                  _decision != 'unavailable' && _source == 'external_supplier'
                  ? _supplier.text.trim()
                  : null,
              reason: _decision == 'full' ? null : _reason.text.trim(),
              followUpDate: _decision == 'unavailable'
                  ? _followUp!.toIso8601String().split('T').first
                  : null,
            ),
          );
        },
        child: Text(
          YorksV1CompanyMaterialRequestStrings.reviewItems.active(
            widget.language,
          ),
        ),
      ),
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 500 ? 110 : 180,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.action,
    this.onPressed,
  });
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null && onPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

String _stateLabel(String state, AppLanguage language) => switch (state) {
  'draft' => YorksV1CompanyMaterialRequestStrings.privateDraft.active(language),
  'approved_for_procurement' =>
    YorksV1CompanyMaterialRequestStrings.approvedForProcurement.active(
      language,
    ),
  'returned_for_changes' =>
    YorksV1CompanyMaterialRequestStrings.returnedForChanges.active(language),
  'rejected' => YorksV1CompanyMaterialRequestStrings.rejected.active(language),
  'arranging' => YorksV1CompanyMaterialRequestStrings.arranging.active(
    language,
  ),
  'ready_for_delivery' =>
    YorksV1CompanyMaterialRequestStrings.readyForDelivery.active(language),
  'partially_dispatched' =>
    YorksV1MaterialRequestStrings.partiallyDispatched.active(language),
  'receipt_pending' =>
    YorksV1CompanyMaterialRequestStrings.receiptPending.active(language),
  'partially_received' =>
    YorksV1CompanyMaterialRequestStrings.partiallyReceived.active(language),
  'awaiting_beneficiary_handover' =>
    YorksV1CompanyMaterialRequestStrings.awaitingHandover.active(language),
  'fulfilled' => YorksV1CompanyMaterialRequestStrings.fulfilled.active(
    language,
  ),
  'closed' => YorksV1CompanyMaterialRequestStrings.closed.active(language),
  'cancelled' => YorksV1CompanyMaterialRequestStrings.cancelled.active(
    language,
  ),
  _ => YorksV1CompanyMaterialRequestStrings.awaitingApproval.active(language),
};

String _currentOwner(String state, AppLanguage language) => switch (state) {
  'submitted_pending_approval' || 'awaiting_company_approval' =>
    YorksV1CompanyMaterialRequestStrings.companyApprover.active(language),
  'approved_for_procurement' ||
  'arranging' ||
  'ready_for_delivery' ||
  'partially_dispatched' =>
    YorksV1CompanyMaterialRequestStrings.procurementOwner.active(language),
  'receipt_pending' =>
    YorksV1CompanyMaterialRequestStrings.authorizedReceiver.active(language),
  'awaiting_beneficiary_handover' =>
    YorksV1CompanyMaterialRequestStrings.beneficiary.active(language),
  'closed' || 'rejected' || 'cancelled' => _stateLabel(state, language),
  _ => YorksV1CompanyMaterialRequestStrings.requesterOwner.active(language),
};

String _nextAction(String state, AppLanguage language) => switch (state) {
  'submitted_pending_approval' || 'awaiting_company_approval' =>
    YorksV1CompanyMaterialRequestStrings.reviewAndDecide.active(language),
  'approved_for_procurement' || 'arranging' =>
    YorksV1CompanyMaterialRequestStrings.arrangeSupply.active(language),
  'draft' => YorksV1CompanyMaterialRequestStrings.resumeDraft.active(language),
  'returned_for_changes' =>
    YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(language),
  'ready_for_delivery' || 'partially_dispatched' =>
    YorksV1CompanyMaterialRequestStrings.dispatch.active(language),
  'receipt_pending' =>
    YorksV1CompanyMaterialRequestStrings.confirmReceipt.active(language),
  'partially_received' =>
    YorksV1CompanyMaterialRequestStrings.arrangeItems.active(language),
  'awaiting_beneficiary_handover' =>
    YorksV1CompanyMaterialRequestStrings.confirmHandover.active(language),
  'fulfilled' => YorksV1CompanyMaterialRequestStrings.closeRequest.active(
    language,
  ),
  'closed' || 'rejected' || 'cancelled' => _stateLabel(state, language),
  _ => YorksV1CompanyMaterialRequestStrings.awaitResolution.active(language),
};

String _decisionLabel(
  YorksV1CompanyMaterialRequestDecisionType type,
  AppLanguage language,
) => switch (type) {
  YorksV1CompanyMaterialRequestDecisionType.approved =>
    YorksV1CompanyMaterialRequestStrings.approve.active(language),
  YorksV1CompanyMaterialRequestDecisionType.returned =>
    YorksV1CompanyMaterialRequestStrings.returnForChanges.active(language),
  YorksV1CompanyMaterialRequestDecisionType.rejected =>
    YorksV1CompanyMaterialRequestStrings.reject.active(language),
};

String _decisionWireLabel(String decision, AppLanguage language) =>
    switch (decision) {
      'approved' => YorksV1CompanyMaterialRequestStrings.approve.active(
        language,
      ),
      'returned' =>
        YorksV1CompanyMaterialRequestStrings.returnForChanges.active(language),
      _ => YorksV1CompanyMaterialRequestStrings.reject.active(language),
    };
