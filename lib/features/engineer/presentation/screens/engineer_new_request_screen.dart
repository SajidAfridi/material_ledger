import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Create Material Requisition screen.
///
/// Mobile: single column (project → notes → items list).
/// Web (≥840): two-panel layout — left: project + notes, right: requested items table.
class EngineerNewRequestScreen extends ConsumerStatefulWidget {
  const EngineerNewRequestScreen({super.key});

  @override
  ConsumerState<EngineerNewRequestScreen> createState() =>
      _EngineerNewRequestScreenState();
}

class _EngineerNewRequestScreenState
    extends ConsumerState<EngineerNewRequestScreen> {
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final selectedProject = ref.read(selectedProjectProvider);
    final lineItems = ref.read(draftLineItemsProvider);

    if (selectedProject == null) {
      _showError(AppStrings.selectProjectRequired.primary);
      return;
    }
    if (lineItems.isEmpty) {
      _showError(AppStrings.addAtLeastOneItem.primary);
      return;
    }

    setState(() => _saving = true);

    ref
        .read(materialRequestsProvider.notifier)
        .addRequest(
          projectName: selectedProject.name,
          projectNameSecondary: selectedProject.nameSecondary,
          itemCount: lineItems.length,
          lineItems: lineItems,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          siteLocation: selectedProject.siteLocation,
        );

    // Clear draft state
    ref.read(draftLineItemsProvider.notifier).clear();
    ref.read(selectedProjectProvider.notifier).state = null;
    _notesController.clear();

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.requestSubmitted.primary),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
    context.go(RoutePaths.engineerHome);
  }

  void _saveDraft() {
    final selectedProject = ref.read(selectedProjectProvider);
    final lineItems = ref.read(draftLineItemsProvider);

    if (selectedProject == null && lineItems.isEmpty) {
      _showError('Add a project or items to save a draft');
      return;
    }

    ref
        .read(materialRequestsProvider.notifier)
        .saveDraft(
          projectName: selectedProject?.name ?? 'Untitled Draft',
          projectNameSecondary: selectedProject?.nameSecondary ?? '',
          itemCount: lineItems.length,
          lineItems: lineItems,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          siteLocation: selectedProject?.siteLocation,
        );

    // Clear draft state
    ref.read(draftLineItemsProvider.notifier).clear();
    ref.read(selectedProjectProvider.notifier).state = null;
    _notesController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.draftSaved.primary),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
    context.go(RoutePaths.engineerHome);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return SafeArea(
      child: Column(
        children: [
          // Scrollable content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ─── Title ──────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.createMaterialRequisition.primary,
                          style: GoogleFonts.inter(
                            fontSize: isWide ? 32 : 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        if (isWide)
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  AppStrings.createReqSubtitle.primary,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const Gap(AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.createReqSubtitle.secondary(lang),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.createReqSubtitle.primary,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const Gap(AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.createReqSubtitle.secondary(lang),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

                // ─── Body ───────────────────────────────────
                if (isWide)
                  _buildWideLayout(lang)
                else
                  _buildMobileLayout(lang),

                const SliverGap(AppSpacing.colossal),
              ],
            ),
          ),

          // ─── Bottom Action Bar ─────────────────────────
          _BottomActionBar(
            onSaveDraft: _saveDraft,
            onSubmit: _saving ? null : _submit,
            isLoading: _saving,
            lang: lang,
          ),
        ],
      ),
    );
  }

  // ─── Wide: Two-Panel Layout ──────────────────────────────────
  Widget _buildWideLayout(AppLanguage lang) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left panel: Project + Notes
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProjectSelector(lang: lang),
                  const Gap(AppSpacing.xxl),
                  _NotesSection(controller: _notesController, lang: lang),
                  const Gap(AppSpacing.xxl),
                  _StockAvailabilityBanner(lang: lang),
                ],
              ),
            ),
            const Gap(AppSpacing.xxl),
            // Right panel: Items table
            Expanded(flex: 3, child: _RequestedItemsSection(lang: lang)),
          ],
        ),
      ),
    );
  }

  // ─── Mobile: Single Column Layout ────────────────────────────
  Widget _buildMobileLayout(AppLanguage lang) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectSelector(lang: lang),
            const Gap(AppSpacing.xxl),
            _NotesSection(controller: _notesController, lang: lang),
            const Gap(AppSpacing.xxl),
            _StockAvailabilityBanner(lang: lang),
            const Gap(AppSpacing.xxl),
            _RequestedItemsSection(lang: lang),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROJECT SELECTOR
// ═══════════════════════════════════════════════════════════════════

class _ProjectSelector extends ConsumerWidget {
  const _ProjectSelector({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final selected = ref.watch(selectedProjectProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualText(
          english: AppStrings.selectProject.primary,
          secondary: AppStrings.selectProject.secondary(lang),
          englishStyle: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selected?.id,
            hint: Text(
              AppStrings.selectProject.primary,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            dropdownColor: AppColors.surfaceContainerLowest,
            items: projects.map((p) {
              return DropdownMenuItem(
                value: p.id,
                child: Text(
                  p.name,
                  style: AppTypography.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final project = projects.firstWhere((p) => p.id == id);
              ref.read(selectedProjectProvider.notifier).state = project;
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTES SECTION
// ═══════════════════════════════════════════════════════════════════

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.controller, required this.lang});
  final TextEditingController controller;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualText(
          english: AppStrings.generalNotes.primary,
          secondary: AppStrings.generalNotes.secondary(lang),
          englishStyle: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(AppSpacing.md),
        TextFormField(
          controller: controller,
          maxLines: isWide ? 5 : 3,
          style: isWide ? AppTypography.bodyLarge : AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: AppStrings.generalNotesPlaceholder.primary,
            hintStyle:
                (isWide ? AppTypography.bodyLarge : AppTypography.bodyMedium)
                    .copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
          ),
        ),
        const Gap(AppSpacing.sm),
        Text(
          AppStrings.generalNotesHelper.primary,
          style: AppTypography.bodySmall,
        ),
        const Gap(AppSpacing.xxs),
        Text(
          AppStrings.generalNotesHelper.secondary(lang),
          style: TextStyle(
            fontSize: 10,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STOCK AVAILABILITY BANNER
// ═══════════════════════════════════════════════════════════════════

class _StockAvailabilityBanner extends StatelessWidget {
  const _StockAvailabilityBanner({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.stockAvailability.primary,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  AppStrings.stockAvailabilityDesc.primary,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REQUESTED ITEMS SECTION
// ═══════════════════════════════════════════════════════════════════

class _RequestedItemsSection extends ConsumerWidget {
  const _RequestedItemsSection({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineItems = ref.watch(draftLineItemsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return LedgerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? AppSpacing.xxl : AppSpacing.lg,
              AppSpacing.xl,
              isWide ? AppSpacing.xxl : AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: BilingualText(
                    english: AppStrings.requestedItems.primary,
                    secondary: AppStrings.requestedItems.secondary(lang),
                    englishStyle: isWide
                        ? AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          )
                        : AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                ),
                _AddItemButton(lang: lang),
              ],
            ),
          ),

          // Column headers (wide only)
          if (isWide && lineItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      AppStrings.materialName.primary.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      AppStrings.quantity.primary.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      AppStrings.unit.primary.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      AppStrings.action.primary,
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          if (lineItems.isNotEmpty) const Gap(AppSpacing.sm),

          // Items
          ...lineItems.map(
            (item) => _RequestedItemRow(
              item: item,
              lang: lang,
              isWide: isWide,
              onRemove: () => ref
                  .read(draftLineItemsProvider.notifier)
                  .removeItem(item.materialId),
              onQuantityChanged: (qty) => ref
                  .read(draftLineItemsProvider.notifier)
                  .updateQuantity(item.materialId, qty),
            ),
          ),

          // Empty state
          if (lineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.colossal),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      size: 48,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                    ),
                    const Gap(AppSpacing.md),
                    Text(
                      AppStrings.addMoreItems.primary,
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          const Gap(AppSpacing.md),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADD ITEM BUTTON (opens picker)
// ═══════════════════════════════════════════════════════════════════

class _AddItemButton extends ConsumerWidget {
  const _AddItemButton({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMaterialPicker(context, ref),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? AppSpacing.lg : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
              const Gap(AppSpacing.xs),
              Text(
                isWide
                    ? '${AppStrings.addNewItem.primary} | ${AppStrings.addNewItem.secondary(lang)}'
                    : AppStrings.addNewItem.primary,
                style: GoogleFonts.inter(
                  fontSize: isWide ? 12 : 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaterialPicker(BuildContext context, WidgetRef ref) {
    final materials = ref.read(materialsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Handle
                const Gap(AppSpacing.md),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Text(
                    AppStrings.selectMaterial.primary,
                    style: AppTypography.titleLarge,
                  ),
                ),
                const Gap(AppSpacing.lg),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: materials.length,
                    separatorBuilder: (_, _) =>
                        const Gap(AppSpacing.listItemGap),
                    itemBuilder: (_, index) {
                      final m = materials[index];
                      return LedgerCard(
                        onTap: () {
                          ref
                              .read(draftLineItemsProvider.notifier)
                              .addItem(
                                RequestLineItem(
                                  materialId: m.id,
                                  materialName: m.name,
                                  materialNameSecondary: m.urduName,
                                  quantity: 1,
                                  unitSymbol: m.unit.symbol,
                                ),
                              );
                          Navigator.of(ctx).pop();
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name, style: AppTypography.titleSmall),
                                  if (m.urduName.isNotEmpty)
                                    Text(
                                      m.urduName,
                                      style: AppTypography.bodySmall,
                                      textDirection: TextDirection.rtl,
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              m.unit.symbol.toUpperCase(),
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REQUESTED ITEM ROW
// ═══════════════════════════════════════════════════════════════════

class _RequestedItemRow extends StatefulWidget {
  const _RequestedItemRow({
    required this.item,
    required this.lang,
    required this.isWide,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final RequestLineItem item;
  final AppLanguage lang;
  final bool isWide;
  final VoidCallback onRemove;
  final ValueChanged<double> onQuantityChanged;

  @override
  State<_RequestedItemRow> createState() => _RequestedItemRowState();
}

class _RequestedItemRowState extends State<_RequestedItemRow> {
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _RequestedItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qtyController.text = widget.item.quantity.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWide) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.materialName,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.item.materialNameSecondary.isNotEmpty)
                    Text(
                      widget.item.materialNameSecondary,
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                      textDirection: TextDirection.rtl,
                    ),
                ],
              ),
            ),
            // Quantity input
            Expanded(
              flex: 1,
              child: SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    final qty = double.tryParse(v);
                    if (qty != null && qty > 0) {
                      widget.onQuantityChanged(qty);
                    }
                  },
                ),
              ),
            ),
            // Unit chip
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    widget.item.unitSymbol.toUpperCase(),
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            // Delete
            SizedBox(
              width: 48,
              child: Center(
                child: IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  iconSize: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: compact card row
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.materialName,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.item.materialNameSecondary.isNotEmpty)
                  Text(
                    widget.item.materialNameSecondary,
                    style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    textDirection: TextDirection.rtl,
                  ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          SizedBox(
            width: 64,
            child: TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
              onChanged: (v) {
                final qty = double.tryParse(v);
                if (qty != null && qty > 0) widget.onQuantityChanged(qty);
              },
            ),
          ),
          const Gap(AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              widget.item.unitSymbol.toUpperCase(),
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.error,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM ACTION BAR
// ═══════════════════════════════════════════════════════════════════

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.onSaveDraft,
    required this.onSubmit,
    required this.isLoading,
    required this.lang,
  });

  final VoidCallback onSaveDraft;
  final VoidCallback? onSubmit;
  final bool isLoading;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? AppSpacing.xxl : AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: AppSpacing.ambientBlur,
            offset: Offset.zero,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Save as Draft
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSaveDraft,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? AppSpacing.xl : AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    isWide
                        ? '${AppStrings.saveAsDraft.primary} | ${AppStrings.saveAsDraft.secondary(lang)}'
                        : AppStrings.saveAsDraft.primary,
                    style: GoogleFonts.inter(
                      fontSize: isWide ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Gap(isWide ? AppSpacing.lg : AppSpacing.md),
            // Submit
            Expanded(
              child: PrimaryButton(
                label: AppStrings.submitRequest.primary,
                icon: Icons.send_rounded,
                isLoading: isLoading,
                isExpanded: true,
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
