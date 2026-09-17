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
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_provider.dart';

class YorksV1CompanyMaterialRequestApprovalInboxScreen extends ConsumerWidget {
  const YorksV1CompanyMaterialRequestApprovalInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final inbox = ref.watch(yorksV1CompanyMaterialRequestApprovalInboxProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.approvalInbox.active(language),
        ),
        actions: [
          IconButton(
            tooltip: YorksV1CompanyMaterialRequestStrings.retry.active(
              language,
            ),
            onPressed: () => ref.invalidate(
              yorksV1CompanyMaterialRequestApprovalInboxProvider,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('company-request-new-from-inbox'),
        onPressed: () => context.push('/yorks/material-requests/company/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          YorksV1CompanyMaterialRequestStrings.companyUse.active(language),
        ),
      ),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          icon: Icons.cloud_off_outlined,
          message: YorksV1CompanyMaterialRequestStrings.decisionFailed.active(
            language,
          ),
          action: YorksV1CompanyMaterialRequestStrings.retry.active(language),
          onPressed: () => ref.invalidate(
            yorksV1CompanyMaterialRequestApprovalInboxProvider,
          ),
        ),
        data: (items) => items.isEmpty
            ? _Message(
                icon: Icons.task_alt_rounded,
                message: YorksV1CompanyMaterialRequestStrings.noApprovals
                    .active(language),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(
                  yorksV1CompanyMaterialRequestApprovalInboxProvider.future,
                ),
                child: ListView(
                  key: const ValueKey('company-approval-inbox-list'),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 104),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              YorksV1CompanyMaterialRequestStrings.approvals
                                  .active(language),
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              YorksV1CompanyMaterialRequestStrings
                                  .approvalInboxDescription
                                  .active(language),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            for (final item in items) ...[
                              _InboxCard(
                                item: item,
                                language: language,
                                onOpen: () => context.push(
                                  '/yorks/material-requests/company/${item.id}',
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

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
    final signature = '${type.wireValue}:${reason.value ?? ''}';
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
          icon: Icons.lock_outline_rounded,
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
    child: InkWell(
      key: ValueKey('company-approval-${item.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.approval_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.requestNumber,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.purpose),
                  const SizedBox(height: 8),
                  Text(
                    '${item.categoryName} · ${item.responsibleUnitName} · ${YorksV1CompanyMaterialRequestStrings.itemCount(item.lineCount).active(language)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '${YorksV1CompanyMaterialRequestStrings.requestedBy.active(language)}: ${item.requesterDisplayName}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.requestNumber ?? request.id,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stateLabel(request.state, language),
                style: AppTypography.labelLarge.copyWith(
                  color: request.canDecide ? AppColors.blue : AppColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.purpose,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Fact(
                        label: YorksV1CompanyMaterialRequestStrings
                            .responsibleUnit
                            .active(language),
                        value: request.responsibleUnitName,
                      ),
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
                      _Fact(
                        label: YorksV1CompanyMaterialRequestStrings
                            .deliveryCollectionPoint
                            .active(language),
                        value: request.deliveryCollectionPoint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        YorksV1CompanyMaterialRequestStrings.materialItems
                            .active(language),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      for (final line in request.lines)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(line.displayOrder.toString()),
                          ),
                          title: Text(line.description),
                          subtitle: line.brandOrigin == null
                              ? null
                              : Text(line.brandOrigin!),
                          trailing: Text('${line.quantity} ${line.unit}'),
                        ),
                    ],
                  ),
                ),
              ),
              if (request.decisions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          YorksV1CompanyMaterialRequestStrings.decisionHistory
                              .active(language),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        for (final decision in request.decisions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _decisionWireLabel(decision.decision, language),
                            ),
                            subtitle: Text(
                              [
                                decision.decidedByDisplayName,
                                if (decision.reason != null) decision.reason!,
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              _FulfilmentActions(request: request, language: language),
              if (request.canDecide) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('company-approval-reject'),
                      onPressed: submitting
                          ? null
                          : () => onDecide(
                              YorksV1CompanyMaterialRequestDecisionType
                                  .rejected,
                            ),
                      child: Text(
                        YorksV1CompanyMaterialRequestStrings.reject.active(
                          language,
                        ),
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
                        YorksV1CompanyMaterialRequestStrings.returnForChanges
                            .active(language),
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('company-approval-approve'),
                      onPressed: submitting
                          ? null
                          : () => onDecide(
                              YorksV1CompanyMaterialRequestDecisionType
                                  .approved,
                            ),
                      icon: submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        YorksV1CompanyMaterialRequestStrings.approve.active(
                          language,
                        ),
                      ),
                    ),
                  ],
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

  Future<void> _reviseAndResubmit() async {
    final purpose = TextEditingController(text: widget.request.purpose);
    final delivery = TextEditingController(
      text: widget.request.deliveryCollectionPoint,
    );
    final quantities = {
      for (final line in widget.request.lines)
        line.id: TextEditingController(text: line.quantity),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(
            widget.language,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: purpose,
                decoration: InputDecoration(
                  labelText: YorksV1CompanyMaterialRequestStrings.purpose
                      .active(widget.language),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: delivery,
                decoration: InputDecoration(
                  labelText: YorksV1CompanyMaterialRequestStrings
                      .deliveryCollectionPoint
                      .active(widget.language),
                ),
              ),
              for (final line in widget.request.lines) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: quantities[line.id],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              YorksV1MaterialRequestStrings.cancel.active(widget.language),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref
            .read(yorksV1CompanyMaterialRequestRepositoryProvider)
            .reviseAndResubmit(
              requestId: widget.request.id,
              expectedVersion: widget.request.recordVersion,
              purpose: purpose.text.trim(),
              deliveryCollectionPoint: delivery.text.trim(),
              lines: [
                for (final line in widget.request.lines)
                  {
                    'id': line.id,
                    'item_description': line.description,
                    'brand_origin': line.brandOrigin,
                    'requested_qty': quantities[line.id]!.text.trim(),
                    'unit': line.unit,
                  },
              ],
              idempotencyKey: const Uuid().v4(),
            ),
      );
    }
    purpose.dispose();
    delivery.dispose();
    for (final controller in quantities.values) {
      controller.dispose();
    }
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
    final inventory = await ref.read(
      yorksV1ArrangementInventoryProvider.future,
    );
    if (!mounted) return;
    final lines = <Map<String, Object?>>[];
    for (final line in widget.request.lines) {
      final available = inventory
          .where((item) => item.unit.toLowerCase() == line.unit.toLowerCase())
          .toList(growable: false);
      final result = await showDialog<_PlanChoice>(
        context: context,
        builder: (dialogContext) => _PlanDialog(
          line: line,
          inventory: available,
          language: widget.language,
        ),
      );
      if (result == null || !mounted) return;
      lines.add(result.toPayload(line.id));
    }
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .saveSupplyPlan(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            lines: lines,
            idempotencyKey: const Uuid().v4(),
          ),
    );
  }

  Future<void> _dispatch() async {
    final plan = widget.request.currentSupplyPlan;
    final planLines = plan?['lines'];
    if (planLines is! List) return;
    final lines = <Map<String, Object?>>[];
    for (final raw in planLines.whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      final requestLine = widget.request.lines.firstWhere(
        (line) => line.id == map['request_line_id'],
      );
      final remaining =
          (double.tryParse(map['arranged_qty']?.toString() ?? '') ?? 0) -
          (double.tryParse(requestLine.dispatchedQuantity) ?? 0);
      if (remaining > 0) {
        lines.add({
          'supply_line_id': map['id'],
          'dispatch_qty': remaining.toString(),
        });
      }
    }
    if (lines.isEmpty) return;
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .dispatch(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            lines: lines,
            idempotencyKey: const Uuid().v4(),
          ),
    );
  }

  Future<void> _receive() async {
    if (widget.request.pendingDispatches.isEmpty) return;
    final dispatch = widget.request.pendingDispatches.first;
    final rawLines = dispatch['lines'];
    if (rawLines is! List) return;
    final lines = <Map<String, Object?>>[];
    for (final raw in rawLines.whereType<Map>()) {
      final choice = await showDialog<_ReceiptChoice>(
        context: context,
        builder: (dialogContext) => _ReceiptDialog(
          dispatchedQuantity: raw['dispatched_qty'].toString(),
          language: widget.language,
        ),
      );
      if (choice == null || !mounted) return;
      lines.add(choice.toPayload(raw['id'].toString()));
    }
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .confirmReceipt(
            requestId: widget.request.id,
            dispatchId: dispatch['id'].toString(),
            expectedVersion: widget.request.recordVersion,
            lines: lines,
            idempotencyKey: const Uuid().v4(),
          ),
    );
  }

  Future<void> _handover() async {
    final lines = [
      for (final line in widget.request.unallocatedReceiptLines)
        {'receipt_line_id': line['id'], 'quantity': line['available_qty']},
    ];
    if (lines.isEmpty) return;
    final witnessed =
        widget.request.authorizedReceiver.authUserId !=
        widget.request.beneficiary.authUserId;
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .confirmHandover(
            requestId: widget.request.id,
            expectedVersion: widget.request.recordVersion,
            acknowledgementBasis: witnessed
                ? 'authorized_receiver_witnessed'
                : 'beneficiary_confirmed',
            lines: lines,
            idempotencyKey: const Uuid().v4(),
          ),
    );
  }

  Future<void> _return() async {
    final reason = await _promptReason();
    if (reason == null || !mounted) return;
    final lines = [
      for (final line in widget.request.returnableHandoverLines)
        {'handover_line_id': line['id'], 'quantity': line['returnable_qty']},
    ];
    if (lines.isEmpty) return;
    await _run(
      () => ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .submitReturn(
            requestId: widget.request.id,
            reason: reason,
            lines: lines,
            idempotencyKey: const Uuid().v4(),
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
            idempotencyKey: const Uuid().v4(),
          ),
    );
  }

  Future<String?> _promptReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          YorksV1CompanyMaterialRequestStrings.submitReturn.active(
            widget.language,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.reasonRequired
                .active(widget.language),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              YorksV1MaterialRequestStrings.cancel.active(widget.language),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(
              YorksV1CompanyMaterialRequestStrings.submitReturn.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result;
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
            YorksV1CompanyMaterialRequestStrings.reviseAndResubmit.active(
              widget.language,
            ),
          ),
        ),
      );
    }
    if (widget.request.canPlan) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _plan,
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.saveSupplyPlan.active(
              widget.language,
            ),
          ),
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
                        idempotencyKey: const Uuid().v4(),
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
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1CompanyMaterialRequestStrings.fulfilment.active(
                widget.language,
              ),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        ),
      ),
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
  });
  final String dispatchedQuantity;
  final AppLanguage language;

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  String _outcome = 'received';
  final TextEditingController _good = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _good.text = widget.dispatchedQuantity;
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
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      ],
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
          if (good < 0 ||
              exception < 0 ||
              (_outcome != 'received' && _note.text.trim().isEmpty)) {
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

class _PlanChoice {
  const _PlanChoice({
    required this.decision,
    required this.quantity,
    this.inventoryItemId,
    this.externalSupplier,
    this.reason,
  });
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
    'follow_up_date': decision == 'unavailable'
        ? DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first
        : null,
    'reason': reason,
  };
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({
    required this.line,
    required this.inventory,
    required this.language,
  });
  final YorksV1CompanyMaterialRequestLine line;
  final List<YorksV1InventoryItem> inventory;
  final AppLanguage language;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final TextEditingController _quantity = TextEditingController(
    text: widget.line.quantity,
  );
  final TextEditingController _supplier = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String _decision = 'full';
  String _source = 'warehouse';
  String? _inventoryItemId;

  @override
  void initState() {
    super.initState();
    _inventoryItemId = widget.inventory.firstOrNull?.id;
    if (_inventoryItemId == null) _source = 'external_supplier';
  }

  @override
  void dispose() {
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
              if (value == 'unavailable') _quantity.text = '0';
            }),
          ),
          const SizedBox(height: 12),
          if (_decision != 'unavailable') ...[
            SegmentedButton<String>(
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
              DropdownButtonFormField<String>(
                initialValue: _inventoryItemId,
                items: [
                  for (final item in widget.inventory)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.description} (${item.availableQuantity})',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _inventoryItemId = value),
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
        onPressed: () => Navigator.pop(
          context,
          _PlanChoice(
            decision: _decision,
            quantity: _decision == 'unavailable' ? '0' : _quantity.text.trim(),
            inventoryItemId: _source == 'warehouse' ? _inventoryItemId : null,
            externalSupplier: _source == 'external_supplier'
                ? _supplier.text.trim()
                : null,
            reason: _decision == 'full' ? null : _reason.text.trim(),
          ),
        ),
        child: Text(
          YorksV1CompanyMaterialRequestStrings.saveSupplyPlan.active(
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
  'ready_for_delivery' || 'partially_dispatched' =>
    YorksV1CompanyMaterialRequestStrings.readyForDelivery.active(language),
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
  _ => YorksV1CompanyMaterialRequestStrings.awaitingApproval.active(language),
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
