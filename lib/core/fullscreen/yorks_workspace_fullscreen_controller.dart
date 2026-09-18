import 'package:flutter/foundation.dart';

/// Browser-level fullscreen state for the shared Yorks workspace chrome.
///
/// This is intentionally separate from the fixed-layout inspection zoom. A
/// fullscreen transition changes only the available browser viewport; the
/// existing zoom controller continues to own scale, pan and viewer exclusions.
abstract class YorksWorkspaceFullscreenController extends ChangeNotifier {
  bool get isSupported;

  bool get isFullscreen;

  /// Whether Yorks should temporarily hide its own navigation chrome.
  ///
  /// Browsers without a usable Fullscreen API use this focused workspace mode
  /// so the feature still gives the record surface the full app viewport.
  bool get shouldHideWorkspaceChrome;

  Future<void> toggle();
}
