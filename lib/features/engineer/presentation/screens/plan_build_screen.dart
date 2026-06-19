import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../widgets/custom_item_sheet.dart';
import '../widgets/inventory_picker_sheet.dart';

/// Phase 1 — Engineer builds/edits the material plan, then submits it to
/// procurement (FR-017 – FR-020). Items can come from inventory or be custom.
class PlanBuildScreen extends ConsumerStatefulWidget {
  const PlanBuildScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<PlanBuildScreen> createState() => _PlanBuildScreenState();
}

class _PlanBuildScreenState extends ConsumerState<PlanBuildScreen> {
  static const _uuid = Uuid();
  late List<PlanItem> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(materialPlansProvider.notifier)
        .planForProject(widget.projectId);
    _items = List<PlanItem>.from(existing?.items ?? const []);
  }

  void _setQty(String id, double qty) {
    if (qty < 1) return;
    setState(() {
      _items = [
        for (final i in _items)
          if (i.id == id) i.copyWith(quantity: qty) else i,
      ];
    });
  }

  void _remove(String id) =>
      setState(() => _items = _items.where((i) => i.id != id).toList());

  Future<void> _addFromInventory() async {
    final materials = ref.read(materialsProvider);
    final picked = await InventoryPickerSheet.show(context, materials);
    if (picked == null) return;
    setState(() {
      _items = [
        ..._items,
        PlanItem(
          id: 'pi-${_uuid.v4().substring(0, 6)}',
          description: picked.name,
          descriptionSecondary: picked.urduName,
          quantity: 1,
          unitSymbol: picked.unit.symbol,
        ),
      ];
    });
  }

  Future<void> _addCustom() async {
    final item = await CustomItemSheet.show(context);
    if (item == null) return;
    setState(() => _items = [..._items, item]);
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.emptyPlan.primary)));
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(materialPlansProvider.notifier)
        .submitPlan(widget.projectId, _items);

    // Alert procurement immediately (FR-058), deep-linked to the plan review.
    final lang = ref.read(languageProvider);
    final projectName =
        ref.read(projectsProvider.notifier).byId(widget.projectId)?.name ??
        widget.projectId;
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.plan,
          title: AppStrings.notifNewPlanTitle.primary,
          titleSecondary: AppStrings.notifNewPlanTitle.secondary(lang),
          body: '$projectName · ${_items.length} ${AppStrings.items.primary}',
          refId: widget.projectId,
          route: RoutePaths.planReviewProcurementPath(widget.projectId),
          audience: UserRole.procurement.name,
        );

    await ref.logAudit(
      action: 'Material plan submitted',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: '${_items.length} line items',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.planSubmitted.primary)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.materialPlan.primary,
          secondary: AppStrings.materialPlan.secondary(lang),
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
                    if (project != null)
                      Text(
                        project.name,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const Gap(AppSpacing.sm),
                    Text(
                      AppStrings.buildPlanSubtitle.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.xl),
                    if (_items.isEmpty)
                      _EmptyState()
                    else
                      for (final item in _items) ...[
                        _EditableItemCard(
                          item: item,
                          lang: lang,
                          onInc: () => _setQty(item.id, item.quantity + 1),
                          onDec: () => _setQty(item.id, item.quantity - 1),
                          onRemove: () => _remove(item.id),
                        ),
                        const Gap(AppSpacing.listItemGap),
                      ],
                    const Gap(AppSpacing.lg),
                    SecondaryButton(
                      label: AppStrings.addFromInventory.primary,
                      icon: Icons.inventory_2_outlined,
                      onPressed: _addFromInventory,
                    ),
                    const Gap(AppSpacing.sm),
                    SecondaryButton(
                      label: AppStrings.addCustomItem.primary,
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: _addCustom,
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
                child: PrimaryButton(
                  label: AppStrings.submitToProcurement.primary,
                  icon: Icons.send_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableItemCard extends StatelessWidget {
  const _EditableItemCard({
    required this.item,
    required this.lang,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  final PlanItem item;
  final dynamic lang;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final spec = [
      if (item.size.isNotEmpty) item.size,
      if (item.brand.isNotEmpty) item.brand,
      if (item.ralColour.isNotEmpty) item.ralColour,
    ].join(' · ');

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        item.description,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isCustom) ...[
                      const Gap(AppSpacing.sm),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppColors.tertiary,
                      ),
                    ],
                  ],
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
          if (spec.isNotEmpty) ...[
            const Gap(2),
            Text(
              spec,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const Gap(AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: _QtyStepper(
              quantity: item.quantity,
              unit: item.unitSymbol,
              onInc: onInc,
              onDec: onDec,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.unit,
    required this.onInc,
    required this.onDec,
  });

  final double quantity;
  final String unit;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove_rounded, onTap: onDec),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unit',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: onInc),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          const Icon(
            Icons.playlist_add_rounded,
            size: 40,
            color: AppColors.outlineVariant,
          ),
          const Gap(AppSpacing.md),
          Text(AppStrings.emptyPlan.primary, style: AppTypography.titleSmall),
          const Gap(AppSpacing.xs),
          Text(
            AppStrings.emptyPlanHint.primary,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
