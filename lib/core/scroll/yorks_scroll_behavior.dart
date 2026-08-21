import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Makes dense office tables usable with a regular mouse as well as a
/// trackpad. Horizontal scroll views already support a two-finger gesture and
/// Shift + wheel through Flutter's standard axis modifiers; adding mouse drag
/// gives desktop users a dependable alternative without changing scroll
/// physics or individual feature screens.
class YorksScrollBehavior extends MaterialScrollBehavior {
  const YorksScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
