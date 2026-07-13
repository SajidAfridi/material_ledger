import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Engineer's request list — the entry point to each request's detail,
/// where receipt confirmation and returns live (FR-042).
class RequestsListScreen extends ConsumerWidget {
  const RequestsListScreen({super.key, this.projectName});

  final String? projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(materialRequestsProvider);
    final requests = projectName == null
        ? all
        : all.where((r) => r.projectName == projectName).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.myRequests.primary,
          secondary: AppStrings.myRequests.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: requests.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppColors.outlineVariant,
                    ),
                    const Gap(AppSpacing.lg),
                    Text(
                      AppStrings.noRequestsYet.primary,
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxl,
                ),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                itemBuilder: (context, i) =>
                    _RequestCard(request: requests[i], lang: lang),
              ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.lang});

  final MaterialRequest request;
  final dynamic lang;

  // A distinct icon per status so the four amber states (pending / sourcing /
  // partial / on-hold) are told apart at a glance, not only by reading the label.
  StatusChip _statusChip(RequestStatus s) => switch (s) {
    RequestStatus.draft => StatusChip.info(s.label, icon: Icons.edit_note_rounded),
    RequestStatus.pending =>
      StatusChip.warning(s.label, icon: Icons.schedule_rounded),
    RequestStatus.sourcing =>
      StatusChip.warning(s.label, icon: Icons.shopping_cart_rounded),
    RequestStatus.partial =>
      StatusChip.warning(s.label, icon: Icons.incomplete_circle_rounded),
    RequestStatus.dispatched =>
      StatusChip.info(s.label, icon: Icons.local_shipping_rounded),
    RequestStatus.received =>
      StatusChip.success(s.label, icon: Icons.check_circle_rounded),
    RequestStatus.onHold =>
      StatusChip.warning(s.label, icon: Icons.pause_circle_rounded),
    RequestStatus.cancelled =>
      StatusChip.error(s.label, icon: Icons.cancel_rounded),
  };

  @override
  Widget build(BuildContext context) {
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
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(AppSpacing.sm),
              _statusChip(request.status),
            ],
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Text(
                request.id.toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.md),
              Text(
                '${request.itemCount} · ${DateFormat('MMM d').format(request.requestDate)}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              PendingSyncBadge(request.id),
              if (request.priority == RequestPriority.urgent) ...[
                const Gap(AppSpacing.xs),
                StatusChip.error(request.priority.label),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
