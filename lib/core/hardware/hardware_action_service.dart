import 'package:flutter/services.dart';

import '../feedback/feedback_service.dart';

/// Bridges a rugged device's dedicated physical action button (the orange/yellow
/// side key on Zebra / Sonim / CAT handhelds) to the app's primary action, so a
/// warehouse loader can trigger it without looking down at the screen.
///
/// - **Native**: Android `MainActivity.onKeyDown` forwards the hardware keycode
///   over the `material_ledger/hardware` [MethodChannel] as `primaryAction`.
/// - **Demo**: a physical-keyboard key (F5) is also captured here so the
///   mechanism is testable on a simulator / desktop without rugged hardware.
///
/// Full vendor integration (mapping the exact OEM keycode) needs the device
/// SDK; this is the wired, working seam for it.
class HardwareActionService {
  HardwareActionService(this._onPrimaryAction) {
    _channel.setMethodCallHandler(_handleMethodCall);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  static const _channel = MethodChannel('material_ledger/hardware');

  /// Demo stand-in for the rugged side button on a normal keyboard.
  static const _demoKey = LogicalKeyboardKey.f5;

  final void Function() _onPrimaryAction;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'primaryAction') _fire();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == _demoKey) {
      _fire();
      return true; // consumed
    }
    return false;
  }

  void _fire() {
    AppFeedback.primaryAction();
    _onPrimaryAction();
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }
}
