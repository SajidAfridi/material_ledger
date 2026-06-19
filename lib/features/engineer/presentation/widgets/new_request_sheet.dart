import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';

/// Bottom sheet for creating a new material request.
///
/// Follows the Architectural Ledger design: tonal layering, flat inputs,
/// bilingual labels, priority selector chips, gradient CTA.
class NewRequestSheet extends ConsumerStatefulWidget {
  const NewRequestSheet({super.key});

  /// Show this sheet as a modal bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const NewRequestSheet(),
      ),
    );
  }

  @override
  ConsumerState<NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends ConsumerState<NewRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _secondaryNameController = TextEditingController();
  final _siteLocationController = TextEditingController();
  final _itemCountController = TextEditingController();
  final _notesController = TextEditingController();

  RequestPriority _priority = RequestPriority.normal;
  bool _saving = false;

  @override
  void dispose() {
    _projectNameController.dispose();
    _secondaryNameController.dispose();
    _siteLocationController.dispose();
    _itemCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final itemCount = int.tryParse(_itemCountController.text.trim()) ?? 1;

    ref
        .read(materialRequestsProvider.notifier)
        .addRequest(
          projectName: _projectNameController.text.trim(),
          projectNameSecondary: _secondaryNameController.text.trim(),
          itemCount: itemCount,
          priority: _priority,
          siteLocation: _siteLocationController.text.trim().isNotEmpty
              ? _siteLocationController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Drag Handle ─────────────────────────────
              const Gap(AppSpacing.md),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),

              // ─── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.newRequest.primary,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            AppStrings.newRequest.secondary(lang),
                            style: AppTypography.bodySmall,
                            textDirection: lang.isRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              // ─── Form ────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Name
                        LedgerTextField(
                          controller: _projectNameController,
                          label: AppStrings.projectName.primary,
                          urduHint: AppStrings.projectName.secondary(lang),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? AppStrings.fieldRequired.primary
                              : null,
                        ),
                        const Gap(AppSpacing.lg),

                        // Secondary Name
                        LedgerTextField(
                          controller: _secondaryNameController,
                          label: AppStrings.projectNameSecondary.primary,
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.xl),

                        // Site Location
                        LedgerTextField(
                          controller: _siteLocationController,
                          label: AppStrings.siteLocation.primary,
                          urduHint: AppStrings.siteLocation.secondary(lang),
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.xl),

                        // Item Count
                        LedgerTextField(
                          controller: _itemCountController,
                          label: AppStrings.numberOfItems.primary,
                          hintText: '1',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return AppStrings.fieldRequired.primary;
                            }
                            final n = int.tryParse(v!.trim());
                            if (n == null || n <= 0) {
                              return AppStrings.enterValidItemCount.primary;
                            }
                            return null;
                          },
                        ),
                        const Gap(AppSpacing.xl),

                        // Priority
                        Text(
                          AppStrings.priority.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(AppSpacing.sm),
                        _PrioritySelector(
                          selected: _priority,
                          onChanged: (p) => setState(() => _priority = p),
                          lang: lang,
                        ),
                        const Gap(AppSpacing.xl),

                        // Notes
                        LedgerTextField(
                          controller: _notesController,
                          label: AppStrings.notes.primary,
                          hintText: AppStrings.optional.primary,
                          maxLines: 3,
                        ),
                        const Gap(AppSpacing.xxl),

                        // Submit button
                        PrimaryButton(
                          label: AppStrings.submitRequest.primary,
                          icon: Icons.send_rounded,
                          isLoading: _saving,
                          onPressed: _saving ? null : _submit,
                        ),
                        const Gap(AppSpacing.xxl),
                      ],
                    ),
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

// ─── Priority Selector ──────────────────────────────────────────────
class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.selected,
    required this.onChanged,
    required this.lang,
  });

  final RequestPriority selected;
  final ValueChanged<RequestPriority> onChanged;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RequestPriority.values.map((p) {
        final isSelected = p == selected;
        final (color, icon) = switch (p) {
          RequestPriority.normal => (
            AppColors.success,
            Icons.check_circle_outline_rounded,
          ),
          RequestPriority.urgent => (
            AppColors.warning,
            Icons.warning_amber_rounded,
          ),
        };

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: p != RequestPriority.values.last ? AppSpacing.sm : 0,
            ),
            child: InkWell(
              onTap: () => onChanged(p),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? color : AppColors.onSurfaceVariant,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      p.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? color : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
