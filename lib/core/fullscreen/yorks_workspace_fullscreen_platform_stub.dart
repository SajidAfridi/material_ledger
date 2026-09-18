import 'yorks_workspace_fullscreen_controller.dart';

YorksWorkspaceFullscreenController createYorksWorkspaceFullscreenController() =>
    _UnsupportedYorksWorkspaceFullscreenController();

class _UnsupportedYorksWorkspaceFullscreenController
    extends YorksWorkspaceFullscreenController {
  @override
  bool get isSupported => false;

  @override
  bool get isFullscreen => false;

  @override
  bool get shouldHideWorkspaceChrome => false;

  @override
  Future<void> toggle() async {}
}
