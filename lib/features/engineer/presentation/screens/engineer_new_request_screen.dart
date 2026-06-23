import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/engineer_shell.dart';
import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';
import '../widgets/custom_item_sheet.dart';

/// Create Material Requisition screen (redesigned).
///
/// **Mobile**: Single-column form — project selector → selected items
/// (with "Browse & Add More" link) → notes → submit button.
///
/// **Web (≥840)**: Three-panel layout —
/// left: category sidebar, center: material browsing grid,
/// right: "The Ledger" cart with items, project tag, priority & submit.
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

  Future<void> _submit() async {
    if (_saving) return; // guard against double-submit
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

    final priority = ref.read(selectedPriorityProvider);

    // Await so the stock reservation completes before we navigate away.
    final request = await ref
        .read(materialRequestsProvider.notifier)
        .addRequest(
          projectName: selectedProject.name,
          projectNameSecondary: selectedProject.nameSecondary,
          itemCount: lineItems.length,
          lineItems: lineItems,
          priority: priority,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          siteLocation: selectedProject.siteLocation,
        );

    // Alert procurement immediately (FR-064), deep-linked to the dispatch
    // screen for this request so they can act in one tap.
    final lang = ref.read(languageProvider);
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.request,
          title: AppStrings.notifNewRequestTitle.primary,
          titleSecondary: AppStrings.notifNewRequestTitle.secondary(lang),
          body:
              '${selectedProject.name} · ${lineItems.length} item(s)'
              '${priority == RequestPriority.urgent ? ' · ${AppStrings.urgent.primary}' : ''}',
          refId: request.id,
          route: RoutePaths.dispatchPath(request.id),
          audience: UserRole.procurement.name,
        );

    await ref.logAudit(
      action: 'Material request raised',
      module: AuditModule.materials,
      refId: selectedProject.id,
      detail:
          '${selectedProject.name} · ${lineItems.length} item(s)'
          '${priority == RequestPriority.urgent ? ' · Urgent' : ''}',
    );

    // Clear draft state.
    ref.read(draftLineItemsProvider.notifier).clear();
    ref.read(selectedProjectProvider.notifier).state = null;
    ref.read(selectedPriorityProvider.notifier).state = RequestPriority.normal;
    _notesController.clear();

    if (!mounted) return;
    setState(() => _saving = false);

    showSyncSnack(context, ref, savedLabel: AppStrings.requestSubmitted.primary);
    context.go(RoutePaths.engineerHome);
  }

  /// Remove a line item with an Undo affordance (error recovery).
  void _removeItemWithUndo(RequestLineItem item) {
    ref.read(draftLineItemsProvider.notifier).removeItem(item.materialId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${AppStrings.itemRemoved.primary} · ${item.materialName}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          action: SnackBarAction(
            label: AppStrings.undo.primary,
            onPressed: () =>
                ref.read(draftLineItemsProvider.notifier).addItem(item),
          ),
        ),
      );
  }

  /// Discard the whole draft (project, items, priority, notes) with confirmation.
  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.discardDraft.primary,
          style: AppTypography.titleMedium,
        ),
        content: Text(
          AppStrings.discardDraftBody.primary,
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.discardDraft.primary,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(draftLineItemsProvider.notifier).clear();
    ref.read(selectedProjectProvider.notifier).state = null;
    ref.read(selectedPriorityProvider.notifier).state = RequestPriority.normal;
    _notesController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.draftDiscarded.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }

  /// Create a custom (non-inventory) item with full spec incl. RAL and add it
  /// to the draft request (FR-035).
  Future<void> _addCustomItem() async {
    final PlanItem? item = await CustomItemSheet.show(context);
    if (item == null || !mounted) return;
    ref
        .read(draftLineItemsProvider.notifier)
        .addItem(
          RequestLineItem(
            materialId: 'custom-${item.id}',
            materialName: item.description,
            materialNameSecondary: item.descriptionSecondary,
            quantity: item.quantity,
            unitSymbol: item.unitSymbol,
            spec: [
              item.size,
              item.brand,
              item.ralColour,
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
        );
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
    // Fat-finger guard: if a request is being built, an accidental back-swipe
    // must not silently throw it away. (Tab switches keep it — IndexedStack.)
    final hasDraft = ref.watch(draftLineItemsProvider).isNotEmpty;

    return PopScope(
      canPop: !hasDraft,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        AppFeedback.warning();
        final discard = await _confirmDiscard(context);
        if (!discard) return;
        ref.read(draftLineItemsProvider.notifier).clear();
        ref.read(selectedProjectProvider.notifier).state = null;
        if (context.mounted) context.pop();
      },
      child: isWide ? _buildWideLayout(lang, screenWidth) : _buildMobileLayout(lang),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.discardRequestTitle.primary,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          AppStrings.discardRequestBody.primary,
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.keepEditing.primary,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.discard.primary,
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ═══════════════════════════════════════════════════════════════
  //  MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(AppLanguage lang) {
    final lineItems = ref.watch(draftLineItemsProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final hasDraft = selectedProject != null || lineItems.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          // ─── Title ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.newMaterialRequest.primary,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          AppStrings.newMaterialRequest.secondary(lang),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textDirection: lang.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  if (hasDraft)
                    IconButton(
                      onPressed: _discardDraft,
                      tooltip: AppStrings.discardDraft.primary,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      color: AppColors.error.withValues(alpha: 0.8),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),

          const SliverGap(AppSpacing.xxl),

          // ─── Select Project ────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(child: _ProjectSelector(lang: lang)),
          ),

          const SliverGap(AppSpacing.xl),

          // ─── Priority ──────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(child: _PrioritySelector(lang: lang)),
          ),

          const SliverGap(AppSpacing.xxl),

          // ─── Selected Items Header ─────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: BilingualText(
                      english: AppStrings.selectedItems.primary,
                      secondary: AppStrings.selectedItems.secondary(lang),
                      englishStyle: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (lineItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            size: 14,
                            color: AppColors.onPrimary,
                          ),
                          const Gap(AppSpacing.xs),
                          Text(
                            '${lineItems.length} ${AppStrings.itemsSelected.primary.split(' ').first}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverGap(AppSpacing.lg),

          // ─── Item Cards ────────────────────────────────
          if (lineItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverList.separated(
                itemCount: lineItems.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                itemBuilder: (_, index) {
                  final item = lineItems[index];
                  return _MobileItemCard(
                    item: item,
                    lang: lang,
                    onRemove: () => _removeItemWithUndo(item),
                    onQuantityChanged: (qty) => ref
                        .read(draftLineItemsProvider.notifier)
                        .updateQuantity(item.materialId, qty),
                  );
                },
              ),
            ),

          // ─── Empty State ───────────────────────────────
          if (lineItems.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: LedgerCard(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          size: 48,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
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
              ),
            ),

          const SliverGap(AppSpacing.lg),

          // ─── Browse & Add More Button ──────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(child: _BrowseAndAddButton(lang: lang)),
          ),

          const SliverGap(AppSpacing.sm),

          // ─── Add Custom Item ───────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: SecondaryButton(
                label: AppStrings.addCustomItem.primary,
                icon: Icons.add_circle_outline_rounded,
                onPressed: _addCustomItem,
              ),
            ),
          ),

          const SliverGap(AppSpacing.xxl),

          // ─── Additional Notes ──────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: _NotesSection(controller: _notesController, lang: lang),
            ),
          ),

          const SliverGap(AppSpacing.xxl),

          // ─── Submit Button ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: AppStrings.submitRequest.primary,
                    icon: Icons.send_rounded,
                    isLoading: _saving,
                    isExpanded: true,
                    onPressed: _saving ? null : _submit,
                  ),
                  const Gap(AppSpacing.xs),
                  Center(
                    child: Text(
                      AppStrings.submitRequest.secondary(lang),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        height: 1.5,
                      ),
                      textDirection: lang.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverGap(AppSpacing.colossal),
        ],
      ),
      ),
      floatingActionButton: EngineerOverlayNav.centerButton(),
      floatingActionButtonLocation: EngineerOverlayNav.fabLocation,
      bottomNavigationBar: const EngineerOverlayNav(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WEB / DESKTOP LAYOUT — 3-Panel
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWideLayout(AppLanguage lang, double screenWidth) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Left Sidebar ────────────────────────────
          _WebCategorySidebar(lang: lang),

          // ─── Center Panel: Material Browsing ─────────
          Expanded(flex: 3, child: _WebBrowsingPanel(lang: lang)),

          // ─── Right Panel: The Ledger Cart ────────────
          SizedBox(
            width: screenWidth >= 1200 ? 360 : 320,
            child: _WebLedgerPanel(
              lang: lang,
              notesController: _notesController,
              saving: _saving,
              onSubmit: _saving ? null : _submit,
            ),
          ),
        ],
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
// MOBILE — Priority selector (Normal / Urgent)
// ═══════════════════════════════════════════════════════════════════

class _PrioritySelector extends ConsumerWidget {
  const _PrioritySelector({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = ref.watch(selectedPriorityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualText(
          english: AppStrings.priority.primary,
          secondary: AppStrings.priority.secondary(lang),
          englishStyle: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(AppSpacing.md),
        Row(
          children: [
            _PriorityChip(
              label: AppStrings.normal.primary,
              isSelected: priority == RequestPriority.normal,
              onTap: () => ref.read(selectedPriorityProvider.notifier).state =
                  RequestPriority.normal,
            ),
            const Gap(AppSpacing.sm),
            _PriorityChip(
              label: AppStrings.urgent.primary,
              isSelected: priority == RequestPriority.urgent,
              onTap: () => ref.read(selectedPriorityProvider.notifier).state =
                  RequestPriority.urgent,
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MOBILE — Item Card
// ═══════════════════════════════════════════════════════════════════

class _MobileItemCard extends StatefulWidget {
  const _MobileItemCard({
    required this.item,
    required this.lang,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final RequestLineItem item;
  final AppLanguage lang;
  final VoidCallback onRemove;
  final ValueChanged<double> onQuantityChanged;

  @override
  State<_MobileItemCard> createState() => _MobileItemCardState();
}

class _MobileItemCardState extends State<_MobileItemCard> {
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(
        widget.item.quantity.truncateToDouble() == widget.item.quantity ? 0 : 1,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _MobileItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qtyController.text = widget.item.quantity.toStringAsFixed(
        widget.item.quantity.truncateToDouble() == widget.item.quantity ? 0 : 1,
      );
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Name + spec chip + delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.materialName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.item.spec.isNotEmpty) ...[
                      const Gap(AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          widget.item.spec,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error.withValues(alpha: 0.7),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const Gap(AppSpacing.md),

          // Bottom row: Qty label + input + unit
          Row(
            children: [
              Text(
                'Qty:',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.sm),
              SizedBox(
                width: 64,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    final qty = double.tryParse(v);
                    if (qty != null && qty > 0) {
                      widget.onQuantityChanged(qty);
                    }
                  },
                ),
              ),
              const Gap(AppSpacing.sm),
              Text(
                widget.item.unitSymbol,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MOBILE — "Browse & Add More" Dashed Button
// ═══════════════════════════════════════════════════════════════════

class _BrowseAndAddButton extends StatelessWidget {
  const _BrowseAndAddButton({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Push the material picker ON TOP of the request (not the Browse tab),
        // so adding items returns straight here.
        onTap: () => context.push(RoutePaths.engineerPickMaterials),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.primary.withValues(alpha: 0.3),
            strokeWidth: 1.5,
            radius: AppSpacing.radiusMd,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const Gap(AppSpacing.sm),
                Text(
                  AppStrings.browseAndAddMore.primary,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Gap(AppSpacing.md),
                Text(
                  AppStrings.browseAndAddMore.secondary(lang),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                  textDirection: lang.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded rectangle border.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12.0,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth = 8.0;
  final double dashGap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final extracted = metric.extractPath(distance, end);
        canvas.drawPath(extracted, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      radius != oldDelegate.radius;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualText(
          english: AppStrings.additionalNotesOptional.primary,
          secondary: AppStrings.additionalNotesOptional.secondary(lang),
          englishStyle: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(AppSpacing.md),
        TextFormField(
          controller: controller,
          maxLines: 3,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: AppStrings.generalNotesPlaceholder.primary,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WEB — Left Category Sidebar
// ═══════════════════════════════════════════════════════════════════

class _WebCategorySidebar extends ConsumerWidget {
  const _WebCategorySidebar({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(browseCategoryFilterProvider);

    return Container(
      width: 220,
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.materialOps.primary,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  AppStrings.engineersPortal.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.lg),

          // Categories section label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              AppStrings.categories.primary,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
          ),

          const Gap(AppSpacing.sm),

          // Category items
          _SidebarNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: AppStrings.browse.primary,
            secondary: AppStrings.browse.secondary(lang),
            isActive: currentFilter == BrowseCategoryFilter.all,
            lang: lang,
            onTap: () => ref.read(browseCategoryFilterProvider.notifier).state =
                BrowseCategoryFilter.all,
          ),
          _SidebarNavItem(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
            label: AppStrings.requests.primary,
            secondary: AppStrings.requests.secondary(lang),
            isActive: false,
            lang: lang,
            onTap: () => context.go(RoutePaths.engineerHome),
          ),
          _SidebarNavItem(
            icon: Icons.architecture_outlined,
            activeIcon: Icons.architecture_rounded,
            label: 'Projects',
            secondary: AppStrings.selectProject.secondary(lang),
            isActive: false,
            lang: lang,
            onTap: () => context.go(RoutePaths.engineerProjects),
          ),

          const Gap(AppSpacing.xxl),

          // Structure section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              AppStrings.structure.primary,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
          ),

          const Gap(AppSpacing.sm),

          _SidebarSubItem(
            label: 'Valves & Fittings',
            isActive: currentFilter == BrowseCategoryFilter.valvesFittings,
            onTap: () => ref.read(browseCategoryFilterProvider.notifier).state =
                BrowseCategoryFilter.valvesFittings,
          ),
          _SidebarSubItem(
            label: 'Pipes & Ducts',
            isActive: currentFilter == BrowseCategoryFilter.pipesDucts,
            onTap: () => ref.read(browseCategoryFilterProvider.notifier).state =
                BrowseCategoryFilter.pipesDucts,
          ),
          _SidebarSubItem(
            label: 'Fasteners & Tools',
            isActive: currentFilter == BrowseCategoryFilter.fasteners,
            onTap: () => ref.read(browseCategoryFilterProvider.notifier).state =
                BrowseCategoryFilter.fasteners,
          ),

          const Spacer(),

          // Bottom items
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const Gap(AppSpacing.sm),
                Text(
                  AppStrings.support.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.error.withValues(alpha: 0.6),
                ),
                const Gap(AppSpacing.sm),
                Text(
                  AppStrings.signOut.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error.withValues(alpha: 0.7),
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

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.secondary,
    required this.isActive,
    required this.lang,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String secondary;
  final bool isActive;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          color: isActive
              ? AppColors.primaryFixed.withValues(alpha: 0.15)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      secondary,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                        height: 1.4,
                      ),
                      textDirection: lang.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
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

class _SidebarSubItem extends StatelessWidget {
  const _SidebarSubItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Gap(AppSpacing.xxxl),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WEB — Center Browsing Panel
// ═══════════════════════════════════════════════════════════════════

class _WebBrowsingPanel extends ConsumerWidget {
  const _WebBrowsingPanel({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(webFilteredMaterialsProvider);
    final stockFilter = ref.watch(webStockFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Title ──────────────────────────────────
          Row(
            children: [
              Text(
                '${AppStrings.newMaterialRequest.primary} | ',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface,
                ),
              ),
              Flexible(
                child: Text(
                  AppStrings.newMaterialRequest.secondary(lang),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textDirection: lang.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ),
            ],
          ),

          const Gap(AppSpacing.xs),

          Text(
            'Select materials from the active inventory to add to your ledger.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const Gap(AppSpacing.xxl),

          // ─── Search Bar ─────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Gap(AppSpacing.lg),
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: TextField(
                    onChanged: (query) {
                      ref.read(browseSearchQueryProvider.notifier).state =
                          query;
                    },
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText:
                          '${AppStrings.searchMaterials.primary} | ${AppStrings.searchMaterials.secondary(lang)}',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.lg),

          // ─── Filter Chips ───────────────────────────
          Row(
            children: [
              _StockFilterChip(
                label: AppStrings.allItems.primary,
                isSelected: stockFilter == WebStockFilter.all,
                onTap: () => ref.read(webStockFilterProvider.notifier).state =
                    WebStockFilter.all,
              ),
              const Gap(AppSpacing.sm),
              _StockFilterChip(
                label: AppStrings.availableFilter.primary,
                isSelected: stockFilter == WebStockFilter.available,
                onTap: () => ref.read(webStockFilterProvider.notifier).state =
                    WebStockFilter.available,
              ),
              const Gap(AppSpacing.sm),
              _StockFilterChip(
                label: AppStrings.lowStockFilter.primary,
                isSelected: stockFilter == WebStockFilter.lowStock,
                onTap: () => ref.read(webStockFilterProvider.notifier).state =
                    WebStockFilter.lowStock,
              ),
            ],
          ),

          const Gap(AppSpacing.xxl),

          // ─── Material Grid ──────────────────────────
          Expanded(
            child: materials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const Gap(AppSpacing.md),
                        Text(
                          'No materials found',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          // Fixed card height (not width-dependent) so the card
                          // never overflows on any window size / resolution.
                          mainAxisExtent: 180,
                          crossAxisSpacing: AppSpacing.lg,
                          mainAxisSpacing: AppSpacing.lg,
                        ),
                    itemCount: materials.length,
                    itemBuilder: (_, index) {
                      final m = materials[index];
                      return _WebMaterialCard(material: m, lang: lang);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockFilterChip extends StatelessWidget {
  const _StockFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: isSelected
                ? null
                : Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Web Material Card ─────────────────────────────────────────────

class _WebMaterialCard extends ConsumerWidget {
  const _WebMaterialCard({required this.material, required this.lang});
  final MaterialItem material;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = material.stockStatus == StockStatus.lowStock;
    final isOutOfStock = material.stockStatus == StockStatus.outOfStock;
    final statusLabel = isLowStock
        ? 'LOW STOCK'
        : isOutOfStock
        ? 'OUT OF STOCK'
        : 'IN STOCK';
    final statusColor = isLowStock
        ? AppColors.warning
        : isOutOfStock
        ? AppColors.error
        : AppColors.success;

    return LedgerCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: placeholder image + stock badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 24,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stock badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      material.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(AppSpacing.xs),

          // Secondary name
          Text(
            material.urduName,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.4,
            ),
            textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),

          // Spec info
          Text(
            material.category.label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const Spacer(),

          // Bottom: stock count + add button
          Row(
            children: [
              Expanded(
                child: Text(
                  '${material.formattedQuantity} Available',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isOutOfStock
                      ? null
                      : () {
                          ref
                              .read(draftLineItemsProvider.notifier)
                              .addItem(
                                RequestLineItem(
                                  materialId: material.id,
                                  materialName: material.name,
                                  materialNameSecondary: material.urduName,
                                  quantity: 1,
                                  unitSymbol: material.unit.symbol,
                                  spec: material.category.label,
                                ),
                              );
                        },
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.surfaceContainerHigh
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: isOutOfStock
                          ? AppColors.onSurfaceVariant.withValues(alpha: 0.3)
                          : AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WEB — Right Panel: "The Ledger" Cart
// ═══════════════════════════════════════════════════════════════════

class _WebLedgerPanel extends ConsumerWidget {
  const _WebLedgerPanel({
    required this.lang,
    required this.notesController,
    required this.saving,
    required this.onSubmit,
  });

  final AppLanguage lang;
  final TextEditingController notesController;
  final bool saving;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineItems = ref.watch(draftLineItemsProvider);
    final priority = ref.watch(selectedPriorityProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    return Container(
      color: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.theLedger.primary,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            AppStrings.theLedger.secondary(lang),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textDirection: lang.isRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    if (lineItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        child: Text(
                          '${lineItems.length} ${AppStrings.itemsSelected.primary}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onError,
                          ),
                        ),
                      ),
                  ],
                ),

                const Gap(AppSpacing.xxl),

                // Line items
                if (lineItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.colossal,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 40,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Text(
                            'Click + on materials to add them here',
                            style: AppTypography.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                ...lineItems.map(
                  (item) => _WebLedgerItem(
                    item: item,
                    lang: lang,
                    onRemove: () => ref
                        .read(draftLineItemsProvider.notifier)
                        .removeItem(item.materialId),
                    onQuantityChanged: (qty) => ref
                        .read(draftLineItemsProvider.notifier)
                        .updateQuantity(item.materialId, qty),
                  ),
                ),

                const Gap(AppSpacing.xxl),

                // Project Tag
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${AppStrings.projectTag.primary} | ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          AppStrings.projectTag.secondary(lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textDirection: lang.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                        const Gap(AppSpacing.lg),
                        if (selectedProject?.siteLocation != null)
                          Flexible(
                            child: Text(
                              selectedProject!.siteLocation!,
                              style: AppTypography.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    _ProjectSelector(lang: lang),
                  ],
                ),

                const Gap(AppSpacing.xxl),

                // Priority Level
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${AppStrings.priorityLevel.primary} | ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          AppStrings.priorityLevel.secondary(lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textDirection: lang.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        _PriorityChip(
                          label: AppStrings.normal.primary,
                          isSelected: priority == RequestPriority.normal,
                          onTap: () =>
                              ref
                                      .read(selectedPriorityProvider.notifier)
                                      .state =
                                  RequestPriority.normal,
                        ),
                        const Gap(AppSpacing.sm),
                        _PriorityChip(
                          label: AppStrings.urgent.primary,
                          isSelected: priority == RequestPriority.urgent,
                          onTap: () =>
                              ref
                                      .read(selectedPriorityProvider.notifier)
                                      .state =
                                  RequestPriority.urgent,
                        ),
                      ],
                    ),
                  ],
                ),

                const Gap(AppSpacing.xxl),
              ],
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: AppStrings.submitRequisition.primary,
                  isLoading: saving,
                  isExpanded: true,
                  onPressed: onSubmit,
                ),
                const Gap(AppSpacing.xs),
                Center(
                  child: Text(
                    AppStrings.submitRequisition.secondary(lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      height: 1.5,
                    ),
                    textDirection: lang.isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
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

// ─── Web Ledger Item (with +/- stepper) ────────────────────────────

class _WebLedgerItem extends StatelessWidget {
  const _WebLedgerItem({
    required this.item,
    required this.lang,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final RequestLineItem item;
  final AppLanguage lang;
  final VoidCallback onRemove;
  final ValueChanged<double> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + remove
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.materialName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (item.materialNameSecondary.isNotEmpty)
                      Text(
                        item.materialNameSecondary,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          height: 1.4,
                        ),
                        textDirection: lang.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                iconSize: 18,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const Gap(AppSpacing.md),

          // Quantity stepper
          Row(
            children: [
              // Minus button
              _StepperButton(
                icon: Icons.remove,
                onTap: item.quantity > 1
                    ? () => onQuantityChanged(item.quantity - 1)
                    : null,
              ),
              // Quantity display
              Container(
                width: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                ),
                child: Text(
                  item.quantity.toStringAsFixed(
                    item.quantity.truncateToDouble() == item.quantity ? 0 : 1,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              // Plus button
              _StepperButton(
                icon: Icons.add,
                onTap: () => onQuantityChanged(item.quantity + 1),
              ),
              const Gap(AppSpacing.md),
              Text(
                item.unitSymbol.isNotEmpty
                    ? item.unitSymbol[0].toUpperCase() +
                          item.unitSymbol.substring(1)
                    : '',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ─── Priority Chip ─────────────────────────────────────────────────

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: isSelected
                  ? null
                  : Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
