import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_configuration_provider.dart';

abstract final class YorksV1ControlledUnitStrings {
  static const select = TranslatableString(
    en: 'Select a controlled unit',
    ar: 'اختر وحدة معتمدة',
    ur: 'کنٹرول شدہ یونٹ منتخب کریں',
    hi: 'नियंत्रित इकाई चुनें',
  );
  static const loading = TranslatableString(
    en: 'Loading the controlled unit register…',
    ar: 'جارٍ تحميل سجل الوحدات المعتمدة…',
    ur: 'کنٹرول شدہ یونٹ رجسٹر لوڈ ہو رہا ہے…',
    hi: 'नियंत्रित इकाई रजिस्टर लोड हो रहा है…',
  );
  static const unavailable = TranslatableString(
    en: 'Controlled units are unavailable. New item units stay locked until the register loads.',
    ar: 'الوحدات المعتمدة غير متاحة. تظل وحدات الأصناف الجديدة مقفلة حتى يتم تحميل السجل.',
    ur: 'کنٹرول شدہ یونٹس دستیاب نہیں ہیں۔ رجسٹر لوڈ ہونے تک نئے آئٹم یونٹس مقفل رہیں گے۔',
    hi: 'नियंत्रित इकाइयां उपलब्ध नहीं हैं। रजिस्टर लोड होने तक नई आइटम इकाइयां लॉक रहेंगी।',
  );
  static const tryAgain = TranslatableString(
    en: 'Try again',
    ar: 'حاول مرة أخرى',
    ur: 'دوبارہ کوشش کریں',
    hi: 'फिर से प्रयास करें',
  );
}

List<String> yorksV1LoadedControlledUnits(AsyncValue<List<String>> value) {
  if (value is! AsyncData<List<String>>) return const [];
  return value.value
      .map((unit) => unit.trim())
      .where((unit) => unit.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

bool yorksV1ControlledUnitsReady(AsyncValue<List<String>> value) =>
    yorksV1LoadedControlledUnits(value).isNotEmpty;

/// A server-backed unit picker. It never invents choices while the controlled
/// unit register is loading or unavailable. An existing value remains visible
/// so legacy/persisted records can still be reviewed without being rewritten.
class YorksV1ControlledUnitDropdown extends ConsumerWidget {
  const YorksV1ControlledUnitDropdown({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.isDense = false,
    this.showDependencyStatus = false,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final bool isDense;
  final bool showDependencyStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final unitsAsync = ref.watch(yorksV1ConfigurationUnitCodesProvider);
    final controlledUnits = yorksV1LoadedControlledUnits(unitsAsync);
    final current = value.trim();
    final options = <String>{
      if (current.isNotEmpty) current,
      ...controlledUnits,
    }.toList(growable: false);
    final ready = controlledUnits.isNotEmpty;
    final dropdown = DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: current.isEmpty ? null : current,
      isExpanded: true,
      style: isDense
          ? AppTypography.bodySmall.copyWith(color: AppColors.ink)
          : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: isDense,
        contentPadding: isDense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
            : null,
      ),
      hint: Text(
        ready
            ? YorksV1ControlledUnitStrings.select.active(language)
            : YorksV1ControlledUnitStrings.unavailable.active(language),
        overflow: TextOverflow.ellipsis,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled && ready
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
    if (!showDependencyStatus || ready) return dropdown;
    final loading = unitsAsync.isLoading && !unitsAsync.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dropdown,
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: AppColors.error,
                ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loading
                      ? YorksV1ControlledUnitStrings.loading.active(language)
                      : YorksV1ControlledUnitStrings.unavailable.active(
                          language,
                        ),
                  style: AppTypography.bodySmall.copyWith(
                    color: loading ? AppColors.muted : AppColors.error,
                  ),
                ),
              ),
              if (!loading)
                TextButton(
                  key: const ValueKey('controlled-units-retry'),
                  onPressed: () =>
                      ref.invalidate(yorksV1ConfigurationUnitCodesProvider),
                  child: Text(
                    YorksV1ControlledUnitStrings.tryAgain.active(language),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
