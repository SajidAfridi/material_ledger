import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/material_master.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';

class MaterialMastersScreen extends ConsumerWidget {
  const MaterialMastersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(nexusFeatureFlagsProvider).browseMaterials) {
      return Scaffold(
        appBar: AppBar(title: const Text('Material master data')),
        body: const Center(child: Text('Material masters are not enabled.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Material master data'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'Units'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CategoriesRegister(), _UnitsRegister()],
        ),
      ),
    );
  }
}

class _CategoriesRegister extends ConsumerWidget {
  const _CategoriesRegister();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = [...ref.watch(materialCategoriesProvider)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return _RegisterScaffold(
      intro:
          'Used categories are archived, never deleted. Existing catalogue rows remain traceable.',
      addLabel: 'Add category',
      onAdd: () => _editCategory(context, ref),
      children: [
        for (final value in values)
          _MasterTile(
            title: value.name,
            subtitle: [
              if (value.secondaryName.isNotEmpty) value.secondaryName,
              value.isCustom ? 'Custom' : 'Yorks default',
            ].join(' · '),
            status: value.archived ? 'Archived' : 'Active',
            archived: value.archived,
            onEdit: () => _editCategory(context, ref, value: value),
            onToggle: () => ref
                .read(materialCategoriesProvider.notifier)
                .setArchived(value.id, !value.archived),
          ),
      ],
    );
  }
}

class _UnitsRegister extends ConsumerWidget {
  const _UnitsRegister();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = [...ref.watch(materialUnitsProvider)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return _RegisterScaffold(
      intro:
          'Only approved units appear in material forms. Legacy and Procurement-proposed units wait here for review.',
      addLabel: 'Add custom unit',
      onAdd: () => _editUnit(context, ref),
      children: [
        for (final value in values)
          _MasterTile(
            title: '${value.symbol} — ${value.name}',
            subtitle: [
              if (value.secondaryName.isNotEmpty) value.secondaryName,
              value.isCustom ? 'Custom' : 'Yorks default',
            ].join(' · '),
            status: switch (value.status) {
              UnitReviewStatus.approved => 'Approved',
              UnitReviewStatus.pendingReview => 'Review required',
              UnitReviewStatus.archived => 'Archived',
            },
            archived: value.archived,
            pending: value.status == UnitReviewStatus.pendingReview,
            onEdit: () => _editUnit(context, ref, value: value),
            onApprove: value.status == UnitReviewStatus.pendingReview
                ? () => ref
                      .read(materialUnitsProvider.notifier)
                      .setStatus(value.id, UnitReviewStatus.approved)
                : null,
            onToggle: () => ref
                .read(materialUnitsProvider.notifier)
                .setStatus(
                  value.id,
                  value.archived
                      ? UnitReviewStatus.approved
                      : UnitReviewStatus.archived,
                ),
          ),
      ],
    );
  }
}

class _RegisterScaffold extends StatelessWidget {
  const _RegisterScaffold({
    required this.intro,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String intro;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    intro,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Gap(AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addLabel),
                ),
              ],
            ),
            const Gap(AppSpacing.xl),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  const _MasterTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.archived,
    required this.onEdit,
    required this.onToggle,
    this.pending = false,
    this.onApprove,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool archived;
  final bool pending;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final statusColor = archived
        ? AppColors.onSurfaceVariant
        : pending
        ? AppColors.warning
        : AppColors.success;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        leading: Icon(
          archived ? Icons.archive_outlined : Icons.category_outlined,
          color: statusColor,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                status,
                style: AppTypography.labelSmall.copyWith(color: statusColor),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (choice) {
                if (choice == 'edit') onEdit();
                if (choice == 'approve') onApprove?.call();
                if (choice == 'toggle') onToggle();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onApprove != null)
                  const PopupMenuItem(value: 'approve', child: Text('Approve')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(archived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editCategory(
  BuildContext context,
  WidgetRef ref, {
  MaterialCategoryMaster? value,
}) async {
  final name = TextEditingController(text: value?.name);
  final secondary = TextEditingController(text: value?.secondaryName);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(value == null ? 'Add category' : 'Edit category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          TextField(
            controller: secondary,
            decoration: const InputDecoration(
              labelText: 'Secondary name (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved != true || name.text.trim().isEmpty) return;
  if (value == null) {
    await ref
        .read(materialCategoriesProvider.notifier)
        .add(name: name.text, secondaryName: secondary.text);
  } else {
    await ref
        .read(materialCategoriesProvider.notifier)
        .update(value.id, name: name.text, secondaryName: secondary.text);
  }
  name.dispose();
  secondary.dispose();
}

Future<void> _editUnit(
  BuildContext context,
  WidgetRef ref, {
  MaterialUnitMaster? value,
}) async {
  final name = TextEditingController(text: value?.name);
  final symbol = TextEditingController(text: value?.symbol);
  final secondary = TextEditingController(text: value?.secondaryName);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(value == null ? 'Add custom unit' : 'Edit unit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Unit name'),
          ),
          TextField(
            controller: symbol,
            decoration: const InputDecoration(labelText: 'Symbol'),
          ),
          TextField(
            controller: secondary,
            decoration: const InputDecoration(
              labelText: 'Secondary name (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved != true || name.text.trim().isEmpty || symbol.text.trim().isEmpty) {
    return;
  }
  if (value == null) {
    await ref
        .read(materialUnitsProvider.notifier)
        .add(
          name: name.text,
          symbol: symbol.text,
          secondaryName: secondary.text,
        );
  } else {
    await ref
        .read(materialUnitsProvider.notifier)
        .update(
          value.id,
          name: name.text,
          symbol: symbol.text,
          secondaryName: secondary.text,
        );
  }
  name.dispose();
  symbol.dispose();
  secondary.dispose();
}
