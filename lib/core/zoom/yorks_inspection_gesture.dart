import 'package:flutter/gestures.dart';

/// Joins the arena but never claims a single-finger drag. Two contacts must be
/// down before scrolling has won; adding a finger mid-scroll cannot hijack it.
/// Trackpad pan stays with Scrollable at 100%, and pans the inspection view
/// once magnified. OS accessibility gestures are handled before this layer.
class YorksInspectionGestureRecognizer extends OneSequenceGestureRecognizer {
  YorksInspectionGestureRecognizer()
    : super(
        supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.trackpad},
      );

  void Function(double ratio, Offset previous, Offset current)? onInspect;
  bool Function()? canPan;
  bool Function(Offset position, int viewId)? allowsStart;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (allowsStart?.call(event.position, event.viewId) ?? true) &&
      super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      (allowsStart?.call(event.position, event.viewId) ?? true) &&
      super.isPointerPanZoomAllowed(event);
  final _positions = <int, Offset>{};
  bool _claimed = false;
  int? _trackpad;
  double _lastScale = 1;
  Offset _lastFocal = Offset.zero;

  @override
  String get debugDescription => 'two-finger workspace inspection';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _positions[event.pointer] = event.position;
    if (_positions.length == 2) {
      _claimed = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _trackpad = event.pointer;
    _lastScale = 1;
    _lastFocal = event.position;
    if (canPan?.call() ?? false) {
      _claimed = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _positions.containsKey(event.pointer)) {
      final previous = _positions.values.toList();
      _positions[event.pointer] = event.position;
      if (_claimed && _positions.length == 2) {
        final current = _positions.values.toList();
        final distance = (previous[0] - previous[1]).distance;
        if (distance > 1) {
          onInspect?.call(
            (current[0] - current[1]).distance / distance,
            (previous[0] + previous[1]) / 2,
            (current[0] + current[1]) / 2,
          );
        }
      }
    } else if (event is PointerPanZoomUpdateEvent &&
        event.pointer == _trackpad) {
      if (!_claimed && (event.scale - 1).abs() > .001) {
        _claimed = true;
        resolve(GestureDisposition.accepted);
      }
      final focal = event.position + event.pan;
      if (_claimed) {
        onInspect?.call(event.scale / _lastScale, _lastFocal, focal);
      }
      _lastScale = event.scale;
      _lastFocal = focal;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _positions.remove(event.pointer);
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _positions.remove(pointer);
    if (_trackpad == pointer) _trackpad = null;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    resolve(GestureDisposition.rejected);
    _claimed = false;
    _positions.clear();
    _trackpad = null;
  }
}

/// Space + primary-button drag is available to mice without a middle button.
/// The owner disables it while an editable field holds keyboard focus.
class YorksInspectionMousePanRecognizer extends PanGestureRecognizer {
  YorksInspectionMousePanRecognizer()
    : super(supportedDevices: {PointerDeviceKind.mouse});
  bool Function(PointerDownEvent event)? allowsStart;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      (allowsStart?.call(event) ?? false) &&
      super.isPointerAllowed(event);
}
