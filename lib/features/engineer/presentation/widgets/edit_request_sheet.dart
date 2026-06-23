import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';

/// Lets the engineer trim a still-open request — reduce a line to what's in
/// stock, or drop it — without cancelling the whole request. Reservations are
/// adjusted by the provider; procurement is notified of the change.
class EditRequestSheet extends ConsumerStatefulWidget {
  const EditRequestSheet({super.key, required this.requestId});

  final String requestId;

  static Future<void> show(BuildContext context, String requestId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => EditRequestSheet(requestId: requestId),
    );
  }

  @override
  ConsumerState<EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends ConsumerState<EditRequestSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _removed = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  TextEditingController _controllerFor(RequestLineItem line) =>
      _controllers.putIfAbsent(
        line.materialId,
        () => TextEditingController(text: _fmt(line.quantity)),
      );

  Future<void> _save(MaterialRequest req) async {
    if (_saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(materialRequestsProvider.notifier);
    for (final line in req.lineItems) {
      if (_removed.contains(line.materialId)) {
        await notifier.removeRequestLine(req.id, line.materialId);
        continue;
      }
      final entered =
          double.tryParse(_controllerFor(line).text.trim()) ?? line.quantity;
      if (entered != line.quantity) {
        await notifier.updateRequestLine(req.id, line.materialId, entered);
      }
    }
    final lang = ref.read(languageProvider);
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.request,
          title: AppStrings.notifRequestEditedTitle.primary,
          titleSecondary: AppStrings.notifRequestEditedTitle.secondary(lang),
          body: req.projectName,
          refId: req.id,
          route: RoutePaths.dispatchPath(req.id),
          audience: UserRole.procurement.name,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.requestEdited.primary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = ref
        .watch(materialRequestsProvider)
        .where((r) => r.id == widget.requestId)
        .firstOrNull;
    final materials = ref.watch(materialsProvider);
    if (req == null) return const SizedBox.shrink();

    double onHand(String id) {
      for (final m in materials) {
        if (m.id == id) return m.quantity;
      }
      return 0;
    }

    final remaining = req.lineItems.where((l) => !_removed.contains(l.materialId));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.editRequest.primary,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final line in req.lineItems)
                    _EditLine(
                      line: line,
                      onHand: onHand(line.materialId),
                      controller: _controllerFor(line),
                      removed: _removed.contains(line.materialId),
                      onToggleRemove: () => setState(() {
                        if (!_removed.add(line.materialId)) {
                          _removed.remove(line.materialId);
                        }
                      }),
                      onUseAvailable: () {
                        final avail = onHand(line.materialId);
                        _controllerFor(line).text = _fmt(avail);
                      },
                      fmt: _fmt,
                    ),
                ],
              ),
            ),
          ),
          const Gap(AppSpacing.lg),
          PrimaryButton(
            label: AppStrings.saveChanges.primary,
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: (_saving || remaining.isEmpty)
                ? null
                : () => _save(req),
          ),
        ],
      ),
    );
  }
}

class _EditLine extends StatelessWidget {
  const _EditLine({
    required this.line,
    required this.onHand,
    required this.controller,
    required this.removed,
    required this.onToggleRemove,
    required this.onUseAvailable,
    required this.fmt,
  });

  final RequestLineItem line;
  final double onHand;
  final TextEditingController controller;
  final bool removed;
  final VoidCallback onToggleRemove;
  final VoidCallback onUseAvailable;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    final short = onHand < line.quantity;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
      child: LedgerCard(
        color: removed
            ? AppColors.errorContainer.withValues(alpha: 0.15)
            : AppColors.surfaceContainerLowest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.materialName,
                    style: AppTypography.titleSmall.copyWith(
                      decoration: removed ? TextDecoration.lineThrough : null,
                      color: removed ? AppColors.onSurfaceVariant : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onToggleRemove,
                  icon: Icon(
                    removed
                        ? Icons.undo_rounded
                        : Icons.delete_outline_rounded,
                    color: removed ? AppColors.primary : AppColors.error,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              '${AppStrings.available.primary}: ${fmt(onHand)} ${line.unitSymbol}',
              style: AppTypography.labelSmall.copyWith(
                color: short ? AppColors.error : AppColors.onSurfaceVariant,
                fontWeight: short ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (!removed) ...[
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(line.unitSymbol, style: AppTypography.bodyMedium),
                  const Spacer(),
                  if (short && onHand > 0)
                    TextButton(
                      onPressed: onUseAvailable,
                      child: Text(AppStrings.available.primary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
