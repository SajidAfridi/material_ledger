import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';

/// Procurement/Admin-only server-projected warehouse inventory workspace.
class YorksV1InventoryScreen extends ConsumerStatefulWidget {
  const YorksV1InventoryScreen({super.key});

  @override
  ConsumerState<YorksV1InventoryScreen> createState() =>
      _YorksV1InventoryScreenState();
}

class _YorksV1InventoryScreenState
    extends ConsumerState<YorksV1InventoryScreen> {
  String? _search;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final inventory = ref.watch(yorksV1InventoryWorkspaceProvider(_search));
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _ActiveText(
                copy: YorksV1LogisticsStrings.inventory,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: YorksV1LogisticsStrings.refresh.primary,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ],
            )
          : null,
      floatingActionButton: compactRoute
          ? FloatingActionButton.extended(
              tooltip: YorksV1LogisticsStrings.addStock.primary,
              onPressed: () => _openAdjustment(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(YorksV1LogisticsStrings.addStock.primary),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.pageMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compactRoute) ...[
                    YorksR35PageHeader(
                      eyebrow: YorksV1ShellStrings.procurementWorkspace.primary,
                      title: YorksV1LogisticsStrings.inventory.primary,
                      description:
                          YorksV1LogisticsStrings.movementHistory.primary,
                      actions: [
                        SizedBox(
                          height: AppSpacing.controlHeight,
                          child: OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              YorksV1LogisticsStrings.refresh.primary,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: AppSpacing.minTapTarget,
                          child: FilledButton.icon(
                            onPressed: () => _openAdjustment(context),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              YorksV1LogisticsStrings.addStock.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  TextField(
                    minLines: 1,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: YorksV1LogisticsStrings.searchInventory.primary,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(
                      () =>
                          _search = value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: inventory.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => _InventoryError(onRetry: _refresh),
                      data: (workspace) => workspace.items.isEmpty
                          ? _InventoryEmpty(language: language)
                          : _InventoryList(
                              items: workspace.items,
                              onTap: _openItem,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(yorksV1InventoryWorkspaceProvider(_search));
  }

  Future<void> _openAdjustment(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InventoryAdjustmentDialog(onCommitted: _refresh),
    );
  }

  Future<void> _openItem(YorksV1LogisticsInventoryItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _InventoryItemDetailSheet(
        inventoryItemId: item.id,
        onChanged: _refresh,
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.items, required this.onTap});

  final List<YorksV1LogisticsInventoryItem> items;
  final ValueChanged<YorksV1LogisticsInventoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint) {
          return NexusSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _InventoryHeaderRow(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _InventoryDesktopRow(
                      item: items[index],
                      onTap: () => onTap(items[index]),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _InventoryMobileCard(
            item: items[index],
            onTap: () => onTap(items[index]),
          ),
        );
      },
    );
  }
}

class _InventoryHeaderRow extends StatelessWidget {
  const _InventoryHeaderRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: _ColumnLabel(YorksV1LogisticsStrings.itemDescription),
        ),
        Expanded(
          flex: 2,
          child: _ColumnLabel(YorksV1LogisticsStrings.brandOrigin),
        ),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.onHand)),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.reserved)),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.available)),
      ],
    ),
  );
}

class _InventoryDesktopRow extends StatelessWidget {
  const _InventoryDesktopRow({required this.item, required this.onTap});

  final YorksV1LogisticsInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: _ItemName(item: item)),
              Expanded(flex: 2, child: Text(item.brandOrigin ?? '—')),
              Expanded(
                child: _Quantity(value: item.onHandQuantity, unit: item.unit),
              ),
              Expanded(
                child: _Quantity(value: item.reservedQuantity, unit: item.unit),
              ),
              Expanded(
                child: _Quantity(
                  value: item.availableQuantity,
                  unit: item.unit,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InventoryMobileCard extends StatelessWidget {
  const _InventoryMobileCard({required this.item, required this.onTap});

  final YorksV1LogisticsInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NexusSectionCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemName(item: item),
            if (item.brandOrigin != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.brandOrigin!, style: AppTypography.bodySmall),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.onHand.primary,
                    value: '${item.onHandQuantity} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.reserved.primary,
                    value: '${item.reservedQuantity} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.available.primary,
                    value: '${item.availableQuantity} ${item.unit}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InventoryAdjustmentDialog extends ConsumerStatefulWidget {
  const _InventoryAdjustmentDialog({
    required this.onCommitted,
    this.inventoryItem,
  });

  final VoidCallback onCommitted;
  final YorksV1LogisticsInventoryItem? inventoryItem;

  @override
  ConsumerState<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends ConsumerState<_InventoryAdjustmentDialog> {
  final _description = TextEditingController();
  final _brandOrigin = TextEditingController();
  final _unit = TextEditingController();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _brandOrigin.dispose();
    _unit.dispose();
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(YorksV1LogisticsStrings.addStock.primary),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.inventoryItem == null) ...[
              _TextInput(
                controller: _description,
                label: YorksV1LogisticsStrings.itemDescription.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              _TextInput(
                controller: _brandOrigin,
                label: YorksV1LogisticsStrings.brandOrigin.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              _TextInput(
                controller: _unit,
                label: YorksV1LogisticsStrings.unit.primary,
              ),
              const SizedBox(height: AppSpacing.md),
            ] else
              Text(
                widget.inventoryItem!.description,
                style: AppTypography.titleSmall,
              ),
            _TextInput(
              controller: _quantity,
              label: YorksV1LogisticsStrings.quantity.primary,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TextInput(
              controller: _reason,
              label: YorksV1LogisticsStrings.reason.primary,
            ),
          ],
        ),
      ),
    ),
    actions: [
      SecondaryButton(
        label: MaterialLocalizations.of(context).cancelButtonLabel,
        isExpanded: false,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      PrimaryButton(
        label: YorksV1LogisticsStrings.addStock.primary,
        isExpanded: false,
        isLoading: _saving,
        onPressed: _save,
      ),
    ],
  );

  Future<void> _save() async {
    if ((widget.inventoryItem == null &&
            (_description.text.trim().isEmpty || _unit.text.trim().isEmpty)) ||
        double.tryParse(_quantity.text.trim()) == null ||
        _quantity.text.trim() == '0' ||
        _reason.text.trim().isEmpty) {
      _showFailure();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .adjustInventory(
            YorksV1InventoryAdjustmentInput(
              inventoryItemId: widget.inventoryItem?.id,
              description: widget.inventoryItem == null
                  ? _description.text
                  : null,
              brandOrigin: widget.inventoryItem == null
                  ? _brandOrigin.text
                  : null,
              unit: widget.inventoryItem == null ? _unit.text : null,
              quantityDelta: _quantity.text,
              reason: _reason.text,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onCommitted();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFailure() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(YorksV1LogisticsStrings.savingFailed.primary)),
  );
}

class _InventoryItemDetailSheet extends ConsumerWidget {
  const _InventoryItemDetailSheet({
    required this.inventoryItemId,
    required this.onChanged,
  });

  final String inventoryItemId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      yorksV1InventoryItemDetailProvider(inventoryItemId),
    );
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (context, controller) => detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _InventoryError(
            onRetry: () => ref.invalidate(
              yorksV1InventoryItemDetailProvider(inventoryItemId),
            ),
          ),
          data: (value) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(child: _ItemName(item: value.item)),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _InventoryFacts(item: value.item),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: YorksV1LogisticsStrings.addStock.primary,
                icon: Icons.add_rounded,
                onPressed: () => _adjustItem(context, ref, value.item),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: value.item.isActive
                    ? YorksV1LogisticsStrings.archive.primary
                    : YorksV1LogisticsStrings.reactivate.primary,
                icon: value.item.isActive
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
                onPressed: () => _toggleItem(context, ref, value.item),
              ),
              const SizedBox(height: AppSpacing.lg),
              NexusSectionCard(
                title: YorksV1LogisticsStrings.movementHistory.primary,
                child: value.movements.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          for (final movement in value.movements)
                            _MovementRow(movement: movement),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleItem(
    BuildContext context,
    WidgetRef ref,
    YorksV1LogisticsInventoryItem item,
  ) async {
    final reason = await _reasonDialog(context);
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .setInventoryItemActive(
            YorksV1InventoryItemStateInput(
              inventoryItemId: item.id,
              expectedVersion: item.recordVersion,
              isActive: !item.isActive,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      ref.invalidate(yorksV1InventoryItemDetailProvider(item.id));
      onChanged();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(YorksV1LogisticsStrings.savingFailed.primary)),
        );
      }
    }
  }

  Future<void> _adjustItem(
    BuildContext context,
    WidgetRef ref,
    YorksV1LogisticsInventoryItem item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InventoryAdjustmentDialog(
        inventoryItem: item,
        onCommitted: () {
          ref.invalidate(yorksV1InventoryItemDetailProvider(item.id));
          onChanged();
        },
      ),
    );
  }
}

class _InventoryFacts extends StatelessWidget {
  const _InventoryFacts({required this.item});

  final YorksV1LogisticsInventoryItem item;

  @override
  Widget build(BuildContext context) => NexusSectionCard(
    child: Row(
      children: [
        Expanded(
          child: _Fact(
            label: YorksV1LogisticsStrings.onHand.primary,
            value: '${item.onHandQuantity} ${item.unit}',
          ),
        ),
        Expanded(
          child: _Fact(
            label: YorksV1LogisticsStrings.reserved.primary,
            value: '${item.reservedQuantity} ${item.unit}',
          ),
        ),
        Expanded(
          child: _Fact(
            label: YorksV1LogisticsStrings.available.primary,
            value: '${item.availableQuantity} ${item.unit}',
          ),
        ),
      ],
    ),
  );
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final YorksV1InventoryMovement movement;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Icon(
          movement.quantityDelta.startsWith('-')
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: movement.quantityDelta.startsWith('-')
              ? AppColors.error
              : AppColors.success,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movement.reason, style: AppTypography.bodyMedium),
              Text(
                movement.actorDisplayName,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        Text(movement.quantityDelta, style: AppTypography.titleSmall),
      ],
    ),
  );
}

class _ItemName extends StatelessWidget {
  const _ItemName({required this.item});

  final YorksV1LogisticsInventoryItem item;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      if (!item.isActive)
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm),
          child: Icon(Icons.archive_outlined, size: 18, color: AppColors.muted),
        ),
    ],
  );
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.copy);
  final TranslatableString copy;

  @override
  Widget build(BuildContext context) => Text(
    copy.primary,
    style: AppTypography.labelLarge.copyWith(color: AppColors.muted),
  );
}

class _Quantity extends StatelessWidget {
  const _Quantity({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Text('$value $unit');
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTypography.titleSmall),
    ],
  );
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _InventoryEmpty extends StatelessWidget {
  const _InventoryEmpty({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Center(
    child: _ActiveText(
      copy: YorksV1LogisticsStrings.noInventory,
      language: language,
      center: true,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
    ),
  );
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SecondaryButton(
      label: YorksV1LogisticsStrings.savingFailed.primary,
      icon: Icons.refresh_rounded,
      onPressed: onRetry,
    ),
  );
}

class _ActiveText extends StatelessWidget {
  const _ActiveText({
    required this.copy,
    required this.language,
    required this.style,
    this.center = false,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
    copy.active(language),
    textAlign: center ? TextAlign.center : TextAlign.start,
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
    style: style,
  );
}

Future<String?> _reasonDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(YorksV1LogisticsStrings.reason.primary),
      content: _TextInput(
        controller: controller,
        label: YorksV1LogisticsStrings.reason.primary,
      ),
      actions: [
        SecondaryButton(
          label: MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          isExpanded: false,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PrimaryButton(
          label: YorksV1LogisticsStrings.confirmReceipt.primary,
          isExpanded: false,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
