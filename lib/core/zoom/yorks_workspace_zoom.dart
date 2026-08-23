import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// Flutter surfaces physical mouse wheel movement in logical pixels. A
  /// conventional wheel notch is usually close to 72 pixels, while
  /// high-resolution wheels split that same physical notch over multiple
  /// smaller events. Scaling proportionally keeps both inputs predictable and
  /// caps an unusually large free-spin event at one controlled zoom step.
  static const double _wheelNotchDelta = 72;

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

  /// Converts a physical wheel delta into one bounded scale adjustment.
  ///
  /// Negative [scrollDeltaY] is wheel-up and therefore zooms in. The result is
  /// intentionally proportional rather than one full [step] per event: a
  /// high-resolution wheel can emit several events for a single detent without
  /// producing an extreme jump.
  double scaleDeltaForWheelDelta(double scrollDeltaY) {
    if (scrollDeltaY.abs() < .001) return 0;
    final normalizedNotches = (scrollDeltaY.abs() / _wheelNotchDelta)
        .clamp(0, 1)
        .toDouble();
    return (scrollDeltaY.isNegative ? 1 : -1) * step * normalizedNotches;
  }

  /// Pans the transformed scene by a mouse drag delta. Panning is meaningful
  /// only once the scene is magnified; at 100% it remains pinned to the normal
  /// route layout.
  void panBy(Offset viewportDelta) {
    if (currentScale <= minimumScale + .001) return;
    final translation = _transformationController.value.getTranslation();
    setTransformation(
      _matrixFor(
        currentScale,
        Offset(
          translation.x + viewportDelta.dx,
          translation.y + viewportDelta.dy,
        ),
      ),
    );
  }

  /// Lets the viewport animate a matrix without routing high-frequency gesture
  /// frames through Riverpod or rebuilding business widgets.
  void setTransformation(Matrix4 value) {
    final constrained = _constrainedTransformation(value);
    if (_sameMatrix(_transformationController.value, constrained)) return;
    _transformationController.value = constrained;
  }

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
  int? _middlePanPointer;

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
    if (event is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
        if (!mounted || resolved is! PointerScaleEvent) return;
        _animateToScale(
          _controller.currentScale * resolved.scale,
          focalPoint: resolved.localPosition,
        );
      });
      return;
    }
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    // Shift-wheel is a horizontal-scroll affordance in desktop browsers and
    // tables. It must never become a surprise zoom shortcut, even if a user
    // also happens to hold Ctrl or Command.
    if (keyboard.isShiftPressed ||
        (!keyboard.isControlPressed && !keyboard.isMetaPressed)) {
      return;
    }
    if (event.scrollDelta.dy.abs() < .01) return;

    // This Listener is the front-most hit-test target only for pointer
    // signals. Registering first consumes modified wheel input before an
    // underlying page/table Scrollable can also process it. Ordinary wheel
    // and two-finger scrolling do not register here and stay untouched.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!mounted || resolved is! PointerScrollEvent) return;
      final delta = _controller.scaleDeltaForWheelDelta(
        resolved.scrollDelta.dy,
      );
      if (delta == 0) return;
      // localPosition is the pointer's actual location in this viewport, so
      // the value under a physical mouse cursor remains anchored as it grows.
      _animateToScale(
        _controller.currentScale + delta,
        focalPoint: resolved.localPosition,
      );
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons & kMiddleMouseButton == 0 ||
        _controller.currentScale <= _controller.minimumScale + .001) {
      return;
    }
    _disposeAnimation();
    setState(() => _middlePanPointer = event.pointer);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _middlePanPointer ||
        event.buttons & kMiddleMouseButton == 0) {
      return;
    }
    _controller.panBy(event.delta);
  }

  void _endMiddlePan(PointerEvent event) {
    if (event.pointer != _middlePanPointer) return;
    setState(() => _middlePanPointer = null);
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
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => MouseRegion(
            cursor: _middlePanPointer != null
                ? SystemMouseCursors.grabbing
                : _controller.currentScale > _controller.minimumScale + .001
                ? SystemMouseCursors.grab
                : SystemMouseCursors.basic,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  key: const ValueKey('yorks-workspace-zoom-viewport'),
                  transformationController:
                      _controller.transformationController,
                  minScale: _controller.minimumScale,
                  maxScale: _controller.maximumScale,
                  alignment: Alignment.topLeft,
                  boundaryMargin: EdgeInsets.zero,
                  constrained: true,
                  clipBehavior: Clip.hardEdge,
                  // One-finger scrolling belongs to the route's existing nested
                  // scrollables. A canvas pan would steal that familiar behavior.
                  panEnabled: false,
                  // Mouse/trackpad scale signals are handled by the passthrough
                  // layer so that only Ctrl/Command-wheel can zoom. Keeping the
                  // built-in wheel scaling off is what lets normal and Shift wheel
                  // events reach their native page/table Scrollable.
                  scaleEnabled: false,
                  trackpadScrollCausesScale: false,
                  child: widget.child,
                ),
                // A transparent front listener wins only Ctrl/Command wheel input
                // and an active middle-button drag. It does not register ordinary
                // or Shift wheel signals, so normal nested page/table scrolling is
                // still resolved by the route below.
                Positioned.fill(
                  child: _YorksPointerPassthroughLayer(
                    onPointerSignal: _handlePointerSignal,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _endMiddlePan,
                    onPointerCancel: _endMiddlePan,
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
          ),
        ),
      );
    },
  );
}

/// Sits above the workspace in paint order without becoming its input target.
///
/// It deliberately adds itself to the hit-test path, then returns `false` so
/// the normal page/table child is still hit-tested. That makes this layer the
/// first [PointerSignalResolver] registrant for Ctrl/Command-wheel zoom while
/// preserving every unmodified pointer event for the existing route widgets.
class _YorksPointerPassthroughLayer extends LeafRenderObjectWidget {
  const _YorksPointerPassthroughLayer({
    required this.onPointerSignal,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final PointerSignalEventListener onPointerSignal;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _YorksPointerPassthroughRenderBox(
        onPointerSignal: onPointerSignal,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _YorksPointerPassthroughRenderBox renderObject,
  ) {
    renderObject
      ..onPointerSignal = onPointerSignal
      ..onPointerDown = onPointerDown
      ..onPointerMove = onPointerMove
      ..onPointerUp = onPointerUp
      ..onPointerCancel = onPointerCancel;
  }
}

class _YorksPointerPassthroughRenderBox extends RenderBox {
  _YorksPointerPassthroughRenderBox({
    required this.onPointerSignal,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  PointerSignalEventListener onPointerSignal;
  PointerDownEventListener onPointerDown;
  PointerMoveEventListener onPointerMove;
  PointerUpEventListener onPointerUp;
  PointerCancelEventListener onPointerCancel;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    // Let the Stack continue to the route content behind this visual layer.
    return false;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    switch (event) {
      case PointerDownEvent():
        onPointerDown(event);
      case PointerMoveEvent():
        onPointerMove(event);
      case PointerUpEvent():
        onPointerUp(event);
      case PointerCancelEvent():
        onPointerCancel(event);
      case PointerSignalEvent():
        onPointerSignal(event);
      default:
        break;
    }
  }
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
