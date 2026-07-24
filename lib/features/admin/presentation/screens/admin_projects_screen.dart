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
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Admin project oversight (FR-123/317) — view every project and delete any.
/// Searchable so it stays usable as the register grows.
class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() =>
      _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Project p) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      p.name,
      p.clientName ?? '',
      p.siteLocation ?? '',
      p.jobNumber ?? '',
      p.mainContractor ?? '',
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(projectsWithCommercialsProvider);
    final visible = all.where(_matches).toList();

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
          english: AppStrings.projectsAdmin.primary,
          secondary: AppStrings.projectsAdmin.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          if (ref.watch(nexusFeatureFlagsProvider).projects)
            IconButton(
              tooltip: AppStrings.createProject.primary,
              onPressed: () => context.push(RoutePaths.engineerCreateProject),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerHighest,
                    hintText: 'Search name, client, job #',
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
              Expanded(
                child: all.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.noDataYet.primary,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          'No matching projects',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
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
                            _ProjectRow(project: visible[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.project});
  final Project project;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.deleteProject.primary,
          style: AppTypography.titleMedium,
        ),
        content: Text(project.name, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.delete.primary,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ref
        .read(projectsProvider.notifier)
        .deleteProject(project.id);
    if (!deleted) {
      // Blocked: open requests still hold stock reservations against it.
      AppFeedback.warning();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Can't delete — this project still has open material requests. "
            'Close or cancel them first.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    await ref.logAudit(
      action: 'Project deleted by admin',
      module: AuditModule.materials,
      refId: project.id,
      detail: project.name,
    );
    AppFeedback.confirm();
    messenger.showSnackBar(
      SnackBar(content: Text(AppStrings.projectDeleted.primary)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = project.phase;
    final useWorkspace = ref.watch(nexusFeatureFlagsProvider).projects;
    final canDelete = ref.watch(currentRoleProvider).isAdmin;
    return LedgerCard(
      onTap: useWorkspace
          ? () => context.push(RoutePaths.projectWorkspacePath(project.id))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  [
                    if ((project.clientName ?? '').isNotEmpty)
                      project.clientName,
                    if ((project.siteLocation ?? '').isNotEmpty)
                      project.siteLocation,
                  ].whereType<String>().join(' · '),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ([
                  project.jobNumber,
                  project.mainContractor,
                  project.authorityRef,
                ].any((s) => (s ?? '').isNotEmpty)) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    [
                      if ((project.jobNumber ?? '').isNotEmpty)
                        'Job ${project.jobNumber}',
                      if ((project.mainContractor ?? '').isNotEmpty)
                        project.mainContractor,
                      if ((project.authorityRef ?? '').isNotEmpty)
                        project.authorityRef,
                    ].whereType<String>().join(' · '),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Gap(AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (phase != null) _stateChip(phase.state),
                    if (!project.acceptedByProcurement)
                      StatusChip.warning(
                        AppStrings.awaitingProcurementChip.primary,
                        icon: Icons.hourglass_empty_rounded,
                      ),
                    if (project.openRequestCount > 0)
                      StatusChip.warning(
                        '${project.openRequestCount} ${AppStrings.openRequests.primary.toLowerCase()}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (project.contractValueAED != null) ...[
            Text(
              _money(project.contractValueAED!),
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const Gap(AppSpacing.sm),
          ],
          if (canDelete)
            IconButton(
              tooltip: AppStrings.deleteProject.primary,
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.error.withValues(alpha: 0.8),
            ),
        ],
      ),
    );
  }

  /// AED with thousands separators — the contract-value column from the sheet.
  static String _money(double v) =>
      'AED ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  Widget _stateChip(ProjectState s) => switch (s) {
    ProjectState.active => StatusChip.success(s.label),
    ProjectState.planning => StatusChip.info(s.label),
    ProjectState.onHold => StatusChip.warning(s.label),
    ProjectState.completed => StatusChip.success(s.label),
  };
}
