/// Keeps operational item text legible without changing the remainder of a
/// user-entered value. This deliberately is not title casing: model names,
/// manufacturer spelling, measurements and equipment tags keep every
/// character after the first exactly as the user entered it.
String normalizeYorksV1ItemText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return '${trimmed.substring(0, 1).toUpperCase()}${trimmed.substring(1)}';
}

/// Backward-compatible semantic alias used by controlled item descriptions.
String normalizeYorksV1ItemDescription(String value) =>
    normalizeYorksV1ItemText(value);

String? normalizeYorksV1OptionalItemText(Object? value) {
  if (value == null) return null;
  final normalized = normalizeYorksV1ItemText(value.toString());
  return normalized.isEmpty ? null : normalized;
}
