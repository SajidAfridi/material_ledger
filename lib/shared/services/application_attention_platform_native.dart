import 'dart:io';

import 'package:flutter/services.dart';

import 'application_attention_platform.dart';

/// Native desktop support is intentionally narrow and explicit:
///
/// * macOS updates the Dock badge;
/// * Windows updates the taskbar/window title and asks the taskbar for a
///   non-focus-stealing attention flash when the count increases;
/// * iOS updates the application icon count.
///
/// Android and Linux continue to use their system push presentation. Missing
/// platform registration is harmless during a staged client rollout.
YorksApplicationAttentionPlatform createYorksApplicationAttentionPlatform() =>
    const _NativeYorksApplicationAttentionPlatform();

class _NativeYorksApplicationAttentionPlatform
    implements YorksApplicationAttentionPlatform {
  const _NativeYorksApplicationAttentionPlatform();

  static const _channel = MethodChannel('com.yorks.app/application_attention');

  @override
  Future<void> update({
    required int unreadCount,
    required String windowTitle,
    required bool attentionRaised,
  }) async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('setAttention', <String, Object>{
        'unreadCount': unreadCount,
        'attentionRaised': attentionRaised,
      });
    } on MissingPluginException {
      // Older native builds remain usable while the refreshed client rolls out.
    } on PlatformException {
      // OS focus/badging policy is authoritative; the in-app indicator remains.
    }
  }
}
