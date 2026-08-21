import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/app_language.dart';
import '../../shared/models/yorks_v1_zoom_strings.dart';
import '../constants/constants.dart';

/// The transform authority for one R35 workspace route.
///
/// This deliberately owns only a composited [TransformationController]. It
/// never changes MediaQuery, text scale, breakpoints or constraints, so a
/// 200% desktop workspace remains the same desktop layout—visually magnified.
class YorksWorkspaceZoomController extends ChangeNotifier {
  YorksWorkspaceZoomController({
    this.minimumScale = 1,
    this.maximumScale = 4,
    this.step = .125,
  }) : assert(minimumScale > 0),
       assert(maximumScale >= minimumScale),
       _transformationController = TransformationController() {
    _transformationController.addListener(notifyListeners);
  }

  final double minimumScale;
  final double maximumScale;
  final double step;
  final TransformationController _transformationController;

  Size _viewportSize = Size.zero;

  TransformationController get transformationController =>
      _transformationController;

  double get currentScale => _transformationController.value
      .getMaxScaleOnAxis()
      .clamp(minimumScale, maximumScale)
      .toDouble();

  int get percentage => (currentScale * 100).round();
  bool get canZoomIn => currentScale < maximumScale - .001;
  bool get canZoomOut => currentScale > minimumScale + .001;

  /// The central scene is a stable keyboard/control focal point.
  Offset get defaultFocalPoint =>
      Offset(_viewportSize.width / 2, _viewportSize.height / 2);

  /// Updates the visual boundary without affecting the route's normal layout.
  void updateViewportSize(Size size) {
    if (size.isEmpty || size == _viewportSize) return;
    _viewportSize = size;
    setTransformation(
      _constrainedTransformation(_transformationController.value),
    );
  }

  void zoomIn({Offset? focalPoint}) =>
      setScaleAt(currentScale + step, focalPoint ?? defaultFocalPoint);

  void zoomOut({Offset? focalPoint}) =>
      setScaleAt(currentScale - step, focalPoint ?? defaultFocalPoint);

  void reset() => setTransformation(Matrix4.identity());

  void setScale(double scale, {Offset? focalPoint}) =>
      setScaleAt(scale, focalPoint ?? defaultFocalPoint);

  /// Returns a translation/scale matrix that keeps [focalPoint]'s scene
  /// coordinate under the same pixel after the scale changes.
  Matrix4 transformationForScaleAt(double scale, Offset focalPoint) {
    final targetScale = scale.clamp(minimumScale, maximumScale).toDouble();
    final scenePoint = _transformationController.toScene(focalPoint);
    final proposedTranslation = Offset(
      focalPoint.dx - scenePoint.dx * targetScale,
      focalPoint.dy - scenePoint.dy * targetScale,
    );
    return _matrixFor(
      targetScale,
      _clampTranslation(proposedTranslation, targetScale),
    );
  }

  void setScaleAt(double scale, Offset focalPoint) =>
      setTransformation(transformationForScaleAt(scale, focalPoint));

  /// Lets the viewport animate a matrix without routing high-frequency gesture
  /// frames through Riverpod or rebuilding business widgets.
  void setTransformation(Matrix4 value) {
    final constrained = _constrainedTransformation(value);
    if (_sameMatrix(_transformationController.value, constrained)) return;
    _transformationController.value = constrained;
  }

  /// Re-clamps a native pinch/trackpad result at the end of interaction.
  void constrainCurrentTransformation() =>
      setTransformation(_transformationController.value);

  Matrix4 _constrainedTransformation(Matrix4 value) {
    final scale = value
        .getMaxScaleOnAxis()
        .clamp(minimumScale, maximumScale)
        .toDouble();
    final translation = value.getTranslation();
    return _matrixFor(
      scale,
      _clampTranslation(Offset(translation.x, translation.y), scale),
    );
  }

  Offset _clampTranslation(Offset value, double scale) {
    if (_viewportSize.isEmpty) return value;
    // The transformed scene always covers the viewport but cannot be panned
    // into blank space. At 100% both ranges collapse cleanly to zero.
    final minX = _viewportSize.width * (1 - scale);
    final minY = _viewportSize.height * (1 - scale);
    return Offset(
      value.dx.clamp(minX, 0).toDouble(),
      value.dy.clamp(minY, 0).toDouble(),
    );
  }

  Matrix4 _matrixFor(double scale, Offset translation) => Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);

  bool _sameMatrix(Matrix4 left, Matrix4 right) {
    for (var index = 0; index < 16; index++) {
      if ((left.storage[index] - right.storage[index]).abs() > .00001) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// Zooms only a workspace's central route content. Shell navigation, headers,
/// overlays, dialogs, toasts and the controls below remain untransformed.
class YorksWorkspaceZoomViewport extends StatefulWidget {
  const YorksWorkspaceZoomViewport({
    super.key,
    required this.child,
    required this.routeKey,
    required this.language,
    this.controller,
  });

  final Widget child;
  final String routeKey;
  final AppLanguage language;
  final YorksWorkspaceZoomController? controller;

  @override
  State<YorksWorkspaceZoomViewport> createState() =>
      _YorksWorkspaceZoomViewportState();
}

class _YorksWorkspaceZoomViewportState extends State<YorksWorkspaceZoomViewport>
    with TickerProviderStateMixin {
  late YorksWorkspaceZoomController _controller;
  late bool _ownsController;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant YorksWorkspaceZoomViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeAnimation();
      if (_ownsController) _controller.dispose();
      _setController(widget.controller);
    }
    // Zoom is intentionally route-local. A new major page starts at 100% so
    // users never unknowingly enter an unrelated workspace magnified.
    if (oldWidget.routeKey != widget.routeKey) {
      _disposeAnimation();
      _controller.reset();
    }
  }

  void _setController(YorksWorkspaceZoomController? supplied) {
    _ownsController = supplied == null;
    _controller = supplied ?? YorksWorkspaceZoomController();
  }

  @override
  void dispose() {
    _disposeAnimation();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _disposeAnimation() {
    final animationController = _animationController;
    _animationController = null;
    animationController?.dispose();
  }

  void _animateToScale(double targetScale, {Offset? focalPoint}) {
    final end = _controller.transformationForScaleAt(
      targetScale,
      focalPoint ?? _controller.defaultFocalPoint,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.setTransformation(end);
      return;
    }
    _disposeAnimation();
    final begin = Matrix4.copy(_controller.transformationController.value);
    final animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    final animation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOutCubic),
    );
    animationController.addListener(
      () => _controller.setTransformation(animation.value),
    );
    _animationController = animationController;
    animationController.forward().whenCompleteOrCancel(() {
      if (identical(_animationController, animationController)) {
        _animationController = null;
        if (mounted) {
          _controller.setTransformation(end);
        }
        animationController.dispose();
      }
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    if (event.scrollDelta.dy.abs() < .01) return;

    // This Listener is the front-most hit-test target only for pointer
    // signals. Registering first consumes modified wheel input before an
    // underlying page/table Scrollable can also process it. Ordinary wheel
    // and two-finger scrolling do not register here and stay untouched.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!mounted || resolved is! PointerScrollEvent) return;
      final nextScale =
          _controller.currentScale +
          (resolved.scrollDelta.dy < 0 ? _controller.step : -_controller.step);
      _animateToScale(nextScale, focalPoint: resolved.localPosition);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _controller.updateViewportSize(constraints.biggest);
      // Phone widths stay gesture/shortcut-only; compact tablets and desktop
      // keep an explicit, fixed precision control.
      final showControls = constraints.maxWidth > AppSpacing.compactBreakpoint;
      return YorksWorkspaceZoomShortcuts(
        controller: _controller,
        onZoomIn: () =>
            _animateToScale(_controller.currentScale + _controller.step),
        onZoomOut: () =>
            _animateToScale(_controller.currentScale - _controller.step),
        onReset: () => _animateToScale(_controller.minimumScale),
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              key: const ValueKey('yorks-workspace-zoom-viewport'),
              transformationController: _controller.transformationController,
              minScale: _controller.minimumScale,
              maxScale: _controller.maximumScale,
              alignment: Alignment.topLeft,
              boundaryMargin: EdgeInsets.zero,
              constrained: true,
              clipBehavior: Clip.hardEdge,
              // One-finger scrolling belongs to the route's existing nested
              // scrollables. A canvas pan would steal that familiar behavior.
              panEnabled: false,
              scaleEnabled: true,
              // macOS/Windows two-finger swipes continue to scroll; platform
              // PointerScaleEvents still drive native pinch zoom.
              trackpadScrollCausesScale: false,
              onInteractionEnd: (_) =>
                  _controller.constrainCurrentTransformation(),
              child: widget.child,
            ),
            // A transparent front listener wins only Ctrl/Command wheel input.
            // It never claims taps, drags, pinch, hover, selection or normal
            // scrolling, all of which continue to reach the route below.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerSignal: _handlePointerSignal,
              ),
            ),
            if (showControls)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: YorksWorkspaceZoomControls(
                  controller: _controller,
                  language: widget.language,
                  onZoomIn: () => _animateToScale(
                    _controller.currentScale + _controller.step,
                  ),
                  onZoomOut: () => _animateToScale(
                    _controller.currentScale - _controller.step,
                  ),
                  onReset: () => _animateToScale(_controller.minimumScale),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class YorksWorkspaceZoomShortcuts extends StatelessWidget {
  const YorksWorkspaceZoomShortcuts({
    super.key,
    required this.controller,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.child,
  });

  final YorksWorkspaceZoomController controller;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.equal, control: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.minus, control: true):
          _YorksZoomOutIntent(),
      SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
          _YorksZoomOutIntent(),
      SingleActivator(LogicalKeyboardKey.digit0, control: true):
          _YorksZoomResetIntent(),
      SingleActivator(LogicalKeyboardKey.equal, meta: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
          _YorksZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.minus, meta: true):
          _YorksZoomOutIntent(),
      SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true):
          _YorksZoomOutIntent(),
      SingleActivator(LogicalKeyboardKey.digit0, meta: true):
          _YorksZoomResetIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _YorksZoomInIntent: CallbackAction<_YorksZoomInIntent>(
          onInvoke: (_) {
            if (controller.canZoomIn) onZoomIn();
            return null;
          },
        ),
        _YorksZoomOutIntent: CallbackAction<_YorksZoomOutIntent>(
          onInvoke: (_) {
            if (controller.canZoomOut) onZoomOut();
            return null;
          },
        ),
        _YorksZoomResetIntent: CallbackAction<_YorksZoomResetIntent>(
          onInvoke: (_) {
            if (controller.canZoomOut) onReset();
            return null;
          },
        ),
      },
      child: Focus(autofocus: true, child: child),
    ),
  );
}

class _YorksZoomInIntent extends Intent {
  const _YorksZoomInIntent();
}

class _YorksZoomOutIntent extends Intent {
  const _YorksZoomOutIntent();
}

class _YorksZoomResetIntent extends Intent {
  const _YorksZoomResetIntent();
}

/// Fixed desktop/tablet control. It stays outside the transformed scene.
class YorksWorkspaceZoomControls extends StatelessWidget {
  const YorksWorkspaceZoomControls({
    super.key,
    required this.controller,
    required this.language,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final YorksWorkspaceZoomController controller;
  final AppLanguage language;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: YorksV1ZoomStrings.workspaceZoom.active(language),
    child: Material(
      key: const ValueKey('yorks-workspace-zoom-controls'),
      color: AppColors.surfaceContainerLowest,
      elevation: 4,
      shadowColor: AppColors.scrim.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Container(
          height: AppSpacing.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomIconButton(
                icon: Icons.remove_rounded,
                tooltip: YorksV1ZoomStrings.zoomOut.active(language),
                semanticsLabel: YorksV1ZoomStrings.zoomOut.active(language),
                onPressed: controller.canZoomOut ? onZoomOut : null,
              ),
              Semantics(
                label:
                    '${YorksV1ZoomStrings.zoomPercentage.active(language)}: ${controller.percentage}%',
                child: SizedBox(
                  width: 54,
                  child: Text(
                    '${controller.percentage}%',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              _ZoomIconButton(
                icon: Icons.add_rounded,
                tooltip: YorksV1ZoomStrings.zoomIn.active(language),
                semanticsLabel: YorksV1ZoomStrings.zoomIn.active(language),
                onPressed: controller.canZoomIn ? onZoomIn : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: 34,
                child: TextButton(
                  onPressed: controller.canZoomOut ? onReset : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    minimumSize: const Size(58, AppSpacing.minTapTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(
                    YorksV1ZoomStrings.resetZoom.active(language),
                    style: AppTypography.labelMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ZoomIconButton extends StatelessWidget {
  const _ZoomIconButton({
    required this.icon,
    required this.tooltip,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: semanticsLabel,
    child: Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
        ),
        padding: EdgeInsets.zero,
      ),
    ),
  );
}
