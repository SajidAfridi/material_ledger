import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/sync/connectivity_service.dart';
import '../../../../shared/sync/sync_engine.dart';

/// Data & sync status — a window onto the offline outbox: connection state,
/// pending count, and any dead-lettered writes with a Retry. Surfaces the
/// existing sync providers only (no new sync logic).
class DataSyncScreen extends ConsumerWidget {
  const DataSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final state = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final failed = ref.watch(failedSyncProvider);
    final online = ref.watch(isOnlineProvider);

    final (statusLabel, statusColor, statusIcon) = switch (state) {
      SyncState.synced => (AppStrings.allSynced.primary, AppColors.success, Icons.cloud_done_rounded),
      SyncState.syncing => ('Syncing $pending…', AppColors.primary, Icons.cloud_sync_rounded),
      SyncState.offlineQueued => ('Offline · $pending queued', AppColors.warning, Icons.cloud_off_rounded),
      SyncState.error => ('${failed.length} need attention', AppColors.error, Icons.sync_problem_rounded),
    };

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
          english: AppStrings.dataSync.primary,
          secondary: AppStrings.dataSync.secondary(lang),
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
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Status hero ─────────────────────────────────
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    const Gap(AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            online ? 'Connected' : 'No connection',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              // ─── Dead-lettered ops (Retry) ───────────────────
              if (failed.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Needs attention',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.read(syncEngineProvider).retryAll(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry all'),
                    ),
                  ],
                ),
                const Gap(AppSpacing.sm),
                for (final op in failed) ...[
                  LedgerCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_problem_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const Gap(AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(op.label, style: AppTypography.titleSmall),
                              const Gap(AppSpacing.xxs),
                              Text(
                                op.lastError ?? 'Failed',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(syncEngineProvider).retry(op.id),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.listItemGap),
                ],
                const Gap(AppSpacing.md),
              ],

              // ─── Dev: simulate offline ───────────────────────
              LedgerCard(
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simulate offline',
                            style: AppTypography.titleSmall,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            online
                                ? 'Writes sync immediately'
                                : 'Writes queue until reconnect',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: !online,
                      onChanged: (offline) {
                        final c = ref.read(connectivityProvider);
                        if (c is DefaultConnectivity) c.setOnline(!offline);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
