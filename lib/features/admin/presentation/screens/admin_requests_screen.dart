import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';

/// Which slice of requests the admin is looking at.
enum _ReqFilter { all, open, urgent, onHold, closed }

extension on _ReqFilter {
  String get label => switch (this) {
    _ReqFilter.all => 'All',
    _ReqFilter.open => 'Open',
    _ReqFilter.urgent => 'Urgent',
    _ReqFilter.onHold => 'On hold',
    _ReqFilter.closed => 'Closed',
  };
}

/// Admin request oversight (FR-314) — view every request and reject or delete
/// any, regardless of its current status. Searchable + filterable so it stays
/// usable as the request volume grows.
class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() =>
      _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _ReqFilter _filter = _ReqFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _isOpen(MaterialRequest r) =>
      r.status != RequestStatus.received && r.status != RequestStatus.cancelled;

  static bool _isUrgentOpen(MaterialRequest r) =>
      r.priority == RequestPriority.urgent && _isOpen(r);

  bool _matchesFilter(MaterialRequest r) => switch (_filter) {
    _ReqFilter.all => true,
    _ReqFilter.open => _isOpen(r),
    _ReqFilter.urgent => _isUrgentOpen(r),
    _ReqFilter.onHold => r.status == RequestStatus.onHold,
    _ReqFilter.closed => !_isOpen(r),
  };

  bool _matchesQuery(MaterialRequest r) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.projectName.toLowerCase().contains(q) ||
        r.id.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(materialRequestsProvider);

    // Urgent-open first (what needs the admin now), then newest first.
    final visible = all.where(_matchesFilter).where(_matchesQuery).toList()
      ..sort((a, b) {
        final au = _isUrgentOpen(a);
        final bu = _isUrgentOpen(b);
        if (au != bu) return au ? -1 : 1;
        return b.requestDate.compareTo(a.requestDate);
      });

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Search ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerHighest,
                    hintText: 'Search by project or ID',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ─── Status filter ──────────────────────────────
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    for (final f in _ReqFilter.values) ...[
                      _FilterChip(
                        label: f.label,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                      const Gap(AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const Gap(AppSpacing.xs),
              Expanded(
                child: all.isEmpty
                    ? _EmptyState(text: AppStrings.noRequestsYet.primary)
                    : visible.isEmpty
                    ? _EmptyState(text: 'No matching requests')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                          AppSpacing.screenHorizontal,
                          AppSpacing.huge,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const Gap(AppSpacing.listItemGap),
                        itemBuilder: (context, i) =>
                            _RequestRow(request: visible[i]),
                      ),
              ),
            ],
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
    final messenger = ScaffoldMessenger.of(context);
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
    AppFeedback.confirm();
    messenger.showSnackBar(const SnackBar(content: Text('Request rejected')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
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
    AppFeedback.confirm();
    messenger.showSnackBar(
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
            child: Text(title, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LedgerCard(
      onTap: () => context.push(RoutePaths.requestDetailPath(request.id)),
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

// ─── Filter chip ─────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primaryContainer.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const Gap(AppSpacing.md),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
