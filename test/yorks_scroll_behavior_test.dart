import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/scroll/yorks_scroll_behavior.dart';

void main() {
  test(
    'Yorks scroll behavior supports mouse drag and standard axis switching',
    () {
      const behavior = YorksScrollBehavior();

      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
      expect(
        behavior.pointerAxisModifiers,
        containsAll(<LogicalKeyboardKey>[
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.shiftRight,
        ]),
      );
    },
  );
}
