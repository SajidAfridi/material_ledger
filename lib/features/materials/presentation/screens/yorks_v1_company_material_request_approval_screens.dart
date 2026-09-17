import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';

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
