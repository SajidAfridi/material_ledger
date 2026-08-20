import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'application_attention_platform.dart';

/// Uses two progressive layers for browser and installed-PWA users:
///
/// * the document title works in every supported browser tab;
/// * the Web App Badging API gives installed Chrome/Edge/Safari-compatible
///   Yorks apps an OS-level Dock/taskbar/icon badge when available.
///
/// Both calls are feature/permission tolerant. A browser that does not expose
/// the badging API still receives the title indication and the normal FCM alert.
YorksApplicationAttentionPlatform createYorksApplicationAttentionPlatform() =>
    const _WebYorksApplicationAttentionPlatform();

class _WebYorksApplicationAttentionPlatform
    implements YorksApplicationAttentionPlatform {
  const _WebYorksApplicationAttentionPlatform();

  @override
  Future<void> update({
    required int unreadCount,
    required String windowTitle,
    required bool attentionRaised,
  }) async {
    web.document.title = windowTitle;
    try {
      if (unreadCount > 0) {
        await web.window.navigator.setAppBadge(unreadCount).toDart;
      } else {
        await web.window.navigator.clearAppBadge().toDart;
      }
    } catch (_) {
      // The API is only exposed for installed apps in some browsers and can be
      // disabled by enterprise policy. The document title is the safe fallback.
    }
  }
}
