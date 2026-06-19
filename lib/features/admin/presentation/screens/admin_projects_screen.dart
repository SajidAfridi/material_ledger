import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Admin project oversight (FR-123/317) — view every project and delete any.
class AdminProjectsScreen extends ConsumerWidget {
  const AdminProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final projects = ref.watch(projectsProvider);

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
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: projects.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.noDataYet.primary,
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
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                  itemBuilder: (context, i) => _ProjectRow(project: projects[i]),
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
    ref.read(projectsProvider.notifier).deleteProject(project.id);
    await ref.logAudit(
      action: 'Project deleted by admin',
      module: AuditModule.materials,
      refId: project.id,
      detail: project.name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.projectDeleted.primary)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = project.phase;
    return LedgerCard(
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
                    if ((project.clientName ?? '').isNotEmpty) project.clientName,
                    if ((project.siteLocation ?? '').isNotEmpty)
                      project.siteLocation,
                  ].whereType<String>().join(' · '),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (phase != null) _stateChip(phase.state),
                    if (project.openRequestCount > 0)
                      StatusChip.warning(
                        '${project.openRequestCount} ${AppStrings.openRequests.primary.toLowerCase()}',
                      ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _stateChip(ProjectState s) => switch (s) {
    ProjectState.active => StatusChip.success(s.label),
    ProjectState.planning => StatusChip.info(s.label),
    ProjectState.onHold => StatusChip.warning(s.label),
    ProjectState.completed => StatusChip.success(s.label),
  };
}
