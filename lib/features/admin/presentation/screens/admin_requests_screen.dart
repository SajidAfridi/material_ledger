import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';

/// Admin request oversight (FR-314) — view every request and reject or delete
/// any, regardless of its current status.
class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final requests = ref.watch(materialRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.requestsAdmin.primary,
          secondary: AppStrings.requestsAdmin.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: requests.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.noRequestsYet.primary,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.huge,
                  ),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                  itemBuilder: (context, i) => _RequestRow(request: requests[i]),
                ),
        ),
      ),
    );
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request});
  final MaterialRequest request;

  bool get _open =>
      request.status != RequestStatus.received &&
      request.status != RequestStatus.cancelled;

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      AppStrings.rejectRequest.primary,
      request.projectName,
    );
    if (!ok) return;
    await ref
        .read(materialRequestsProvider.notifier)
        .updateStatus(request.id, RequestStatus.cancelled);
    await ref.logAudit(
      action: 'Request rejected by admin',
      module: AuditModule.materials,
      refId: request.id,
      detail: request.projectName,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      AppStrings.deleteRequest.primary,
      request.projectName,
    );
    if (!ok) return;
    await ref.read(materialRequestsProvider.notifier).removeRequest(request.id);
    await ref.logAudit(
      action: 'Request deleted by admin',
      module: AuditModule.materials,
      refId: request.id,
      detail: request.projectName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.requestDeleted.primary)),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(title, style: AppTypography.titleMedium),
        content: Text(body, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              title,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LedgerCard(
      onTap: () =>
          context.push(RoutePaths.requestDetailPath(request.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.projectName,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(AppSpacing.sm),
              _statusChip(request.status),
            ],
          ),
          const Gap(AppSpacing.xxs),
          Text(
            '${request.id.toUpperCase()} · ${request.itemCount} items'
            '${request.priority == RequestPriority.urgent ? ' · ${AppStrings.urgent.primary}' : ''}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_open)
                TextButton.icon(
                  onPressed: () => _reject(context, ref),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: Text(AppStrings.rejectRequest.primary),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                  ),
                ),
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(AppStrings.delete.primary),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(RequestStatus s) => switch (s) {
    RequestStatus.received => StatusChip.success(s.label),
    RequestStatus.dispatched => StatusChip.success(s.label),
    RequestStatus.partial => StatusChip.warning(s.label),
    RequestStatus.cancelled => StatusChip.error(s.label),
    RequestStatus.onHold => StatusChip.warning(s.label),
    _ => StatusChip.info(s.label),
  };
}
