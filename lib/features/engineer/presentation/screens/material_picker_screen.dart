import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../widgets/custom_item_sheet.dart';

/// A focused "add materials" screen pushed ON TOP of the New Request screen.
/// The engineer browses/searches inventory, taps to add items, and can add a
/// custom (not-yet-in-inventory) item — all into the same draft the request
/// reads. "Done" returns them to the request with everything already added, so
/// they never have to re-open the request via the bottom-bar plus button.
class MaterialPickerScreen extends ConsumerStatefulWidget {
  const MaterialPickerScreen({super.key});

  @override
  ConsumerState<MaterialPickerScreen> createState() =>
      _MaterialPickerScreenState();
}

class _MaterialPickerScreenState extends ConsumerState<MaterialPickerScreen> {
  String _query = '';

  void _toggle(MaterialItem m, bool isAdded) {
    final notifier = ref.read(draftLineItemsProvider.notifier);
    if (isAdded) {
      notifier.removeItem(m.id);
    } else {
      AppFeedback.confirm();
      notifier.addItem(
        RequestLineItem(
          materialId: m.id,
          materialName: m.name,
          materialNameSecondary: m.urduName,
          quantity: 1,
          unitSymbol: m.unit.symbol,
        ),
      );
    }
  }

  Future<void> _addCustom() async {
    final PlanItem? item = await CustomItemSheet.show(context);
    if (item == null || !mounted) return;
    AppFeedback.confirm();
    ref.read(draftLineItemsProvider.notifier).addItem(
          RequestLineItem(
            materialId: 'custom-${item.id}',
            materialName: item.description,
            materialNameSecondary: item.descriptionSecondary,
            quantity: item.quantity,
            unitSymbol: item.unitSymbol,
            spec: [item.size, item.brand, item.ralColour]
                .where((s) => s.isNotEmpty)
                .join(' · '),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final materials = ref.watch(materialsProvider);
    final draft = ref.watch(draftLineItemsProvider);
    final addedIds = {for (final l in draft) l.materialId};
    final addedCount = draft.length;

    final q = _query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? materials
        : materials
            .where(
              (m) =>
                  m.name.toLowerCase().contains(q) ||
                  m.urduName.toLowerCase().contains(q) ||
                  m.category.label.toLowerCase().contains(q),
            )
            .toList();

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
          english: AppStrings.addFromInventory.primary,
          secondary: AppStrings.addFromInventory.secondary(lang),
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
            children: [
              // ─── Search ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchParameters.primary,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              // ─── Custom item ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.xs,
                ),
                child: _CustomItemButton(lang: lang, onTap: _addCustom),
              ),
              // ─── Inventory list ─────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    final isAdded = addedIds.contains(m.id);
                    return _PickRow(
                      material: m,
                      isAdded: isAdded,
                      onToggle: () => _toggle(m, isAdded),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // ─── Done ──────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.md,
        ),
        child: PrimaryButton(
          label: addedCount == 0
              ? AppStrings.done.primary
              : '${AppStrings.done.primary} · $addedCount',
          icon: Icons.check_rounded,
          onPressed: () => context.pop(),
        ),
      ),
    );
  }
}

class _CustomItemButton extends StatelessWidget {
  const _CustomItemButton({required this.lang, required this.onTap});

  final dynamic lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.primaryContainer.withValues(alpha: 0.08),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.add_box_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.addCustomItem.primary,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  AppStrings.customItem.secondary(lang),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.material,
    required this.isAdded,
    required this.onToggle,
  });

  final MaterialItem material;
  final bool isAdded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      onTap: onToggle,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  '${material.category.label} · ${material.formattedQuantity} ${material.unit.symbol}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),
          // Add / Added toggle.
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isAdded ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isAdded
                  ? AppColors.success.withValues(alpha: 0.14)
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdded ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: isAdded ? AppColors.success : AppColors.primary,
                ),
                const Gap(4),
                Text(
                  isAdded ? AppStrings.added.primary : AppStrings.addLabel.primary,
                  style: AppTypography.labelMedium.copyWith(
                    color: isAdded ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
