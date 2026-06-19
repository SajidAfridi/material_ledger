import 'package:flutter/services.dart';

/// Centralised tactile + audio feedback for a gloves-on, split-attention
/// industrial environment. Uses only Flutter built-ins (`HapticFeedback`,
/// `SystemSound`) — no extra dependency. Distinct profiles let a worker
/// recognise an interaction without looking at the screen.
class AppFeedback {
  const AppFeedback._();

  /// Light tactile tick when switching navigation tabs.
  static void tabSwitch() {
    HapticFeedback.selectionClick();
  }

  /// Strong double pulse for the primary action (New Request / future scan) —
  /// deliberately different from a normal tab tick.
  static Future<void> primaryAction() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.mediumImpact();
  }

  /// Confirmation for a committed write (record payment, submit request).
  static void confirm() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// A warning buzz for a blocked / destructive prompt.
  static void warning() {
    HapticFeedback.heavyImpact();
  }

  /// Audible alert that cuts through machinery noise — the seam for an
  /// immediate camera/scan action. Plays the platform alert tone today; swap
  /// for a loud custom asset once a barcode/scan action is added.
  static void audioAlert() {
    SystemSound.play(SystemSoundType.alert);
  }
}
