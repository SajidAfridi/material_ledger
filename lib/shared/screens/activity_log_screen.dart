import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_strings.dart';
import '../models/audit_log.dart';
import '../models/user_role.dart';
import '../providers/audit_log_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/session_provider.dart';

/// Read-only audit trail. The list is append-only and never editable from the
/// client (enforced server-side by the Security Rules — activityLog denies all
/// client writes & deletes). Visibility is role-scoped: Admin sees every
/// module; others see only the modules they can access.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  AuditModule? _filter; // null = all visible modules
  String _query = ''; // search by actor / action / detail (FR-323)

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final entries = ref.watch(auditLogProvider);

    final visibleModules = _modulesFor(
      role,
      canRentals: ref.watch(canAccessRentalsProvider),
      canPeople: ref.watch(canAccessPeopleProvider),
    );
    final q = _query.trim().toLowerCase();
    final visible = entries
        .where((e) => visibleModules.contains(e.module))
        .where((e) => _filter == null || e.module == _filter)
        .where(
          (e) =>
              q.isEmpty ||
              e.action.toLowerCase().contains(q) ||
              e.actorName.toLowerCase().contains(q) ||
              e.actorRole.label.toLowerCase().contains(q) ||
              (e.detail ?? '').toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Activity Log'),
        titleTextStyle: AppTypography.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        actions: [
          if (role.isAdmin && visible.isNotEmpty)
            IconButton(
              tooltip: AppStrings.exportAudit.primary,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _exportCsv(visible),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Search (by user / action / detail) ─────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerHighest,
                    hintText: AppStrings.searchAudit.primary,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ─── Module filter ──────────────────────────────
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final m in visibleModules) ...[
                      const Gap(AppSpacing.sm),
                      _FilterChip(
                        label: m.label,
                        selected: _filter == m,
                        onTap: () => setState(() => _filter = m),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(AppSpacing.xs),

              // ─── Entries ────────────────────────────────────
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xxl,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const Gap(AppSpacing.listItemGap),
                        itemBuilder: (context, i) =>
                            _AuditTile(entry: visible[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AuditModule> _modulesFor(
    UserRole role, {
    required bool canRentals,
    required bool canPeople,
  }) {
    if (role.isAdmin) return AuditModule.values.toList();
    return [
      if (role.canAccessMaterials) AuditModule.materials,
      if (canRentals) AuditModule.rentals,
      if (canPeople) AuditModule.people,
      AuditModule.platform,
    ];
  }

  /// Export the audit trail to CSV (FR-326) — copied to the clipboard.
  Future<void> _exportCsv(List<AuditEntry> entries) async {
    String esc(String s) => s.replaceAll(',', ' ').replaceAll('\n', ' ');
    final buffer = StringBuffer('Timestamp,Action,Actor,Role,Module,Detail\n');
    for (final e in entries) {
      buffer.writeln(
        '${e.timestamp.toIso8601String()},${esc(e.action)},'
        '${esc(e.actorName)},${e.actorRole.label},${e.module.label},'
        '${esc(e.detail ?? '')}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.auditCopied.primary)),
    );
  }
}

// ─── Audit tile ──────────────────────────────────────────────────
class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _moduleStyle(entry.module);
    return LedgerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.detail != null) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    entry.detail!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const Gap(AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const Gap(AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        '${entry.actorName} · ${entry.actorRole.label}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      _relativeTime(entry.timestamp),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _moduleStyle(AuditModule module) => switch (module) {
    AuditModule.materials => (Icons.inventory_2_outlined, AppColors.primary),
    AuditModule.rentals => (Icons.store_mall_directory_outlined, AppColors.tertiary),
    AuditModule.people => (Icons.groups_outlined, AppColors.success),
    AuditModule.platform => (Icons.shield_outlined, AppColors.onSurfaceVariant),
  };
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
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
        duration: const Duration(milliseconds: 160),
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const Gap(AppSpacing.md),
          Text(
            'No activity yet',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
