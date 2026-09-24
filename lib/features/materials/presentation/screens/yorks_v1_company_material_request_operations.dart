import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';

class CompanyQuantityItem {
  const CompanyQuantityItem({
    required this.id,
    required this.description,
    required this.unit,
    required this.maximum,
  });
  final String id;
  final String description;
  final String unit;
  final String maximum;
}

class CompanyQuantitySelection {
  const CompanyQuantitySelection(this.quantities, this.reason);
  final Map<String, String> quantities;
  final String? reason;
}

/// A local review only. The caller commits the selected lines through one
/// versioned, idempotent command after this dialog returns.
class CompanyQuantityReview extends StatefulWidget {
  const CompanyQuantityReview({
    required this.title,
    required this.items,
    required this.language,
    this.message,
    this.requireReason = false,
    this.selectAll = false,
    super.key,
  });
  final String title;
  final String? message;
  final List<CompanyQuantityItem> items;
  final AppLanguage language;
  final bool requireReason;
  final bool selectAll;
  @override
  State<CompanyQuantityReview> createState() => _CompanyQuantityReviewState();
}

class _CompanyQuantityReviewState extends State<CompanyQuantityReview> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final _quantities = {
    for (final item in widget.items)
      item.id: TextEditingController(
        text: widget.selectAll ? item.maximum : '0',
      ),
  };
  bool _empty = false;
  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    final selected = {
      for (final item in widget.items)
        if ((double.tryParse(_quantities[item.id]!.text.trim()) ?? 0) > 0)
          item.id: _quantities[item.id]!.text.trim(),
    };
    if (selected.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.pop(
      context,
      CompanyQuantitySelection(
        selected,
        widget.requireReason ? _reason.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: Text(widget.title),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.message ??
                    YorksV1CompanyMaterialRequestStrings.reviewQuantities
                        .active(widget.language),
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.description, style: AppTypography.titleSmall),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey('company-quantity-${item.id}'),
                        controller: _quantities[item.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: YorksV1CompanyMaterialRequestStrings
                              .quantity
                              .active(widget.language),
                          suffixText: item.unit,
                          helperText:
                              '${YorksV1CompanyMaterialRequestStrings.available.active(widget.language)}: ${item.maximum} ${item.unit}',
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          final number = double.tryParse(raw);
                          final maximum = double.tryParse(item.maximum);
                          return !RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(raw) ||
                                  number == null ||
                                  !number.isFinite ||
                                  maximum == null ||
                                  number > maximum
                              ? YorksV1CompanyMaterialRequestStrings
                                    .quantityLimit
                                    .active(widget.language)
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
              if (widget.requireReason)
                TextFormField(
                  key: const ValueKey('company-operation-reason'),
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: YorksV1CompanyMaterialRequestStrings
                        .reasonRequired
                        .active(widget.language),
                  ),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : YorksV1CompanyMaterialRequestStrings.reasonRequired
                            .active(widget.language),
                ),
              if (_empty)
                Text(
                  YorksV1CompanyMaterialRequestStrings.quantityLimit.active(
                    widget.language,
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          YorksV1MaterialRequestStrings.cancel.active(widget.language),
        ),
      ),
      FilledButton(
        key: const ValueKey('company-operation-confirm'),
        onPressed: _confirm,
        child: Text(
          YorksV1CompanyMaterialRequestStrings.confirmSelection.active(
            widget.language,
          ),
        ),
      ),
    ],
  );
}

/// A reviewable basket: users can revisit any line before committing the whole
/// arrangement or receipt. Leaving the workspace has no server effect.
class CompanyLineReview<T> extends StatefulWidget {
  const CompanyLineReview({
    required this.title,
    required this.descriptions,
    required this.language,
    required this.edit,
    required this.summary,
    required this.confirmLabel,
    super.key,
  });
  final String title;
  final List<String> descriptions;
  final AppLanguage language;
  final Future<T?> Function(int index, T? previous) edit;
  final String Function(T value) summary;
  final String confirmLabel;
  @override
  State<CompanyLineReview<T>> createState() => _CompanyLineReviewState<T>();
}

class _CompanyLineReviewState<T> extends State<CompanyLineReview<T>> {
  final Map<int, T> _values = {};
  bool _editing = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: Text(widget.title),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < widget.descriptions.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _values.containsKey(index)
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  color: _values.containsKey(index)
                      ? AppColors.success
                      : AppColors.muted,
                ),
                title: Text(widget.descriptions[index]),
                subtitle: Text(
                  _values.containsKey(index)
                      ? widget.summary(_values[index] as T)
                      : YorksV1CompanyMaterialRequestStrings.notReviewed.active(
                          widget.language,
                        ),
                ),
                trailing: IconButton(
                  key: ValueKey('company-review-line-$index'),
                  tooltip: YorksV1CompanyMaterialRequestStrings.editLine.active(
                    widget.language,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _editing
                      ? null
                      : () async {
                          setState(() => _editing = true);
                          final result = await widget.edit(
                            index,
                            _values[index],
                          );
                          if (!mounted) return;
                          setState(() {
                            if (result != null) _values[index] = result;
                            _editing = false;
                          });
                        },
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _editing ? null : () => Navigator.pop(context),
        child: Text(
          YorksV1MaterialRequestStrings.cancel.active(widget.language),
        ),
      ),
      FilledButton(
        key: const ValueKey('company-review-confirm'),
        onPressed:
            !_editing &&
                widget.descriptions.isNotEmpty &&
                _values.length == widget.descriptions.length
            ? () => Navigator.pop(context, [
                for (var index = 0; index < widget.descriptions.length; index++)
                  _values[index] as T,
              ])
            : null,
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
