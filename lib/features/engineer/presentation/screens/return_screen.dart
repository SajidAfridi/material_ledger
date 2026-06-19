import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_return.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_return_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';
import '../widgets/inventory_picker_sheet.dart';

/// Phase 2 — Engineer returns surplus, wrong, or damaged material to the
/// store, choosing a reason per item (FR-083).
class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({super.key, this.initialProjectName});

  final String? initialProjectName;

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  Project? _project;
  final List<ReturnItem> _items = [];
  bool _busy = false;
  bool _init = false;

  void _ensureProject(List<Project> projects) {
    if (_init || projects.isEmpty) return;
    _init = true;
    Project? match;
    for (final p in projects) {
      if (p.name == widget.initialProjectName) {
        match = p;
        break;
      }
    }
    _project = match ?? projects.first;
  }

  Future<void> _addItem() async {
    final materials = ref.read(materialsProvider);
    final picked = await InventoryPickerSheet.show(context, materials);
    if (picked == null) return;
    setState(() {
      _items.add(
        ReturnItem(
          description: picked.name,
          descriptionSecondary: picked.urduName,
          quantity: 1,
          unitSymbol: picked.unit.symbol,
          materialId: picked.id,
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (_project == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.addItemToReturn.primary)),
      );
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(returnsProvider.notifier)
        .addReturn(
          projectName: _project!.name,
          projectNameSecondary: _project!.nameSecondary,
          items: _items,
        );
    await ref.logAudit(
      action: 'Material returned to store',
      module: AuditModule.materials,
      refId: _project!.id,
      detail: '${_project!.name} · ${_items.length} item(s)',
    );
    if (!mounted) return;
    showSyncSnack(context, ref, savedLabel: AppStrings.returnSubmitted.primary);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final projects = ref.watch(projectsProvider);
    _ensureProject(projects);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.returnToStore.primary,
          secondary: AppStrings.returnToStore.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  children: [
                    Text(
                      AppStrings.returnSubtitle.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    // Project selector
                    LedgerCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.business_rounded,
                            color: AppColors.primary,
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Project>(
                                isExpanded: true,
                                value: _project,
                                hint: Text(AppStrings.selectProject.primary),
                                items: [
                                  for (final p in projects)
                                    DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (p) => setState(() => _project = p),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppSpacing.xl),
                    if (_items.isEmpty)
                      LedgerCard(
                        color: AppColors.surfaceContainerLow,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.assignment_return_outlined,
                              size: 40,
                              color: AppColors.outlineVariant,
                            ),
                            const Gap(AppSpacing.md),
                            Text(
                              AppStrings.addItemToReturn.primary,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < _items.length; i++) ...[
                        _ReturnItemCard(
                          item: _items[i],
                          lang: lang,
                          onInc: () => setState(
                            () => _items[i] = _items[i].copyWith(
                              quantity: _items[i].quantity + 1,
                            ),
                          ),
                          onDec: () => setState(
                            () => _items[i] = _items[i].copyWith(
                              quantity: (_items[i].quantity - 1).clamp(1, 9999),
                            ),
                          ),
                          onReason: (r) => setState(
                            () => _items[i] = _items[i].copyWith(reason: r),
                          ),
                          onRemove: () => setState(() => _items.removeAt(i)),
                        ),
                        const Gap(AppSpacing.listItemGap),
                      ],
                    const Gap(AppSpacing.lg),
                    SecondaryButton(
                      label: AppStrings.addItemToReturn.primary,
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: _addItem,
                    ),
                  ],
                ),
              ),
              Container(
                color: AppColors.surfaceContainerLowest,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      label: AppStrings.submitReturn.primary,
                      icon: Icons.send_rounded,
                      isLoading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      AppStrings.returnSubmitted.primary,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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

class _ReturnItemCard extends StatelessWidget {
  const _ReturnItemCard({
    required this.item,
    required this.lang,
    required this.onInc,
    required this.onDec,
    required this.onReason,
    required this.onRemove,
  });

  final ReturnItem item;
  final dynamic lang;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final ValueChanged<ReturnReason> onReason;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            AppStrings.reason.primary,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in ReturnReason.values)
                _ReasonChip(
                  label: r.label,
                  selected: item.reason == r,
                  onTap: () => onReason(r),
                ),
            ],
          ),
          const Gap(AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Btn(icon: Icons.remove_rounded, onTap: onDec),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unitSymbol}',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _Btn(icon: Icons.add_rounded, onTap: onInc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}
