import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'yorks_workspace_fullscreen_controller.dart';

YorksWorkspaceFullscreenController createYorksWorkspaceFullscreenController() =>
    _WebYorksWorkspaceFullscreenController();

class _WebYorksWorkspaceFullscreenController
    extends YorksWorkspaceFullscreenController {
  _WebYorksWorkspaceFullscreenController() {
    _nativeFullscreenSupported = _detectNativeFullscreenSupport();
    _fullscreenChangeListener = ((web.Event _) => _sync()).toJS;
    web.document.addEventListener(
      'fullscreenchange',
      _fullscreenChangeListener,
    );
    _nativeFullscreen =
        _nativeFullscreenSupported && web.document.fullscreenElement != null;
  }

  late final web.EventListener _fullscreenChangeListener;
  late final bool _nativeFullscreenSupported;
  bool _nativeFullscreen = false;
  bool _focusMode = false;

  @override
  bool get isSupported => true;

  @override
  bool get isFullscreen => _nativeFullscreen || _focusMode;

  @override
  bool get shouldHideWorkspaceChrome => _focusMode;

  @override
  Future<void> toggle() async {
    if (_focusMode) {
      _setFocusMode(false);
      return;
    }
    if (!_nativeFullscreenSupported) {
      _setFocusMode(true);
      return;
    }
    try {
      if (web.document.fullscreenElement != null) {
        await web.document.exitFullscreen().toDart;
      } else {
        final root = web.document.documentElement;
        if (root == null) return;
        await root.requestFullscreen().toDart;
      }
    } catch (_) {
      // Embedded webviews and enterprise browser policy may reject fullscreen
      // after advertising the API. Use the in-app focused workspace fallback.
      _setFocusMode(true);
      return;
    }
    _sync();
  }

  void _sync() {
    if (!_nativeFullscreenSupported) return;
    final next = web.document.fullscreenElement != null;
    if (next == _nativeFullscreen) return;
    _nativeFullscreen = next;
    notifyListeners();
  }

  void _setFocusMode(bool value) {
    if (_focusMode == value) return;
    _focusMode = value;
    notifyListeners();
  }

  bool _detectNativeFullscreenSupport() {
    final root = web.document.documentElement;
    if (root == null) return false;
    try {
      return web.document.hasProperty('fullscreenEnabled'.toJS).toDart &&
          web.document.hasProperty('exitFullscreen'.toJS).toDart &&
          root.hasProperty('requestFullscreen'.toJS).toDart &&
          web.document.fullscreenEnabled;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    web.document.removeEventListener(
      'fullscreenchange',
      _fullscreenChangeListener,
    );
    super.dispose();
  }
}
