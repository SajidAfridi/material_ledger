import 'app_strings.dart';

/// Localized vocabulary for the R35 workspace precision zoom controls.
///
/// The controls are shared shell chrome, rather than feature-specific copy,
/// so they remain consistent across the dense Yorks operational surfaces.
abstract final class YorksV1ZoomStrings {
  static const workspaceZoom = TranslatableString(
    en: 'Workspace zoom',
    ar: 'تكبير مساحة العمل',
    ur: 'ورک اسپیس زوم',
    hi: 'कार्यस्थान ज़ूम',
  );
  static const zoomIn = TranslatableString(
    en: 'Zoom in',
    ar: 'تكبير',
    ur: 'زوم اِن',
    hi: 'ज़ूम इन',
  );
  static const zoomOut = TranslatableString(
    en: 'Zoom out',
    ar: 'تصغير',
    ur: 'زوم آؤٹ',
    hi: 'ज़ूम आउट',
  );
  static const resetZoom = TranslatableString(
    en: 'Reset zoom',
    ar: 'إعادة ضبط التكبير',
    ur: 'زوم ری سیٹ کریں',
    hi: 'ज़ूम रीसेट करें',
  );
  static const zoomPercentage = TranslatableString(
    en: 'Zoom level',
    ar: 'مستوى التكبير',
    ur: 'زوم لیول',
    hi: 'ज़ूम स्तर',
  );
}
