import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import 'sync_engine.dart';

/// A thin, app-wide status strip that tells the user, honestly, whether their
/// work has reached the server yet. It sits at the very top of every shell so
/// no role can ever mistake "saved on device" for "saved on the server".
///
/// States (driven by [syncStatusProvider]):
///  • synced + online  → hidden (no clutter when everything is committed)
///  • syncing          → blue, spinner, "Syncing N change(s)…"
///  • offline-queued   → amber, cloud-off, "Offline · N change(s) queued"
///  • error            → red, "N change(s) need attention" + Retry
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final failed = ref.watch(failedSyncProvider).length;

    final Widget bar;
    switch (status) {
      case SyncState.synced:
        bar = const SizedBox.shrink();
      case SyncState.syncing:
        bar = _Bar(
          key: const ValueKey('syncing'),
          background: AppColors.primaryFixed,
          foreground: AppColors.onPrimaryFixed,
          leading: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.onPrimaryFixed),
            ),
          ),
          label: 'Syncing ${_n(pending)}…',
        );
      case SyncState.offlineQueued:
        bar = _Bar(
          key: const ValueKey('offline'),
          background: AppColors.warningContainer,
          foreground: AppColors.onWarningContainer,
          leading: const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.onWarningContainer,
          ),
          label: 'Offline · ${_n(pending)} queued',
        );
      case SyncState.error:
        bar = _Bar(
          key: const ValueKey('error'),
          background: AppColors.errorContainer,
          foreground: AppColors.onErrorContainer,
          leading: const Icon(
            Icons.sync_problem_rounded,
            size: 16,
            color: AppColors.onErrorContainer,
          ),
          label: '${_n(failed)} need attention',
          action: 'Retry',
          onAction: () => ref.read(syncEngineProvider).retryAll(),
        );
    }

    // Smoothly grow/shrink as the state changes so it never jumps the layout.
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: bar,
      ),
    );
  }

  static String _n(int count) => count == 1 ? '1 change' : '$count changes';
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.label,
    this.action,
    this.onAction,
  });

  final Color background;
  final Color foreground;
  final Widget leading;
  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (action != null)
                GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 15, color: foreground),
                        const SizedBox(width: 4),
                        Text(
                          action!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
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
