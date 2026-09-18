import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'yorks_workspace_fullscreen_controller.dart';
import 'yorks_workspace_fullscreen_platform_stub.dart'
    if (dart.library.js_interop) 'yorks_workspace_fullscreen_platform_web.dart'
    as platform;

export 'yorks_workspace_fullscreen_controller.dart';

final yorksWorkspaceFullscreenControllerProvider =
    ChangeNotifierProvider<YorksWorkspaceFullscreenController>((ref) {
      return platform.createYorksWorkspaceFullscreenController();
    });
