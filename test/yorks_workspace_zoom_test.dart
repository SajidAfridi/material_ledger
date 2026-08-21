import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/zoom/yorks_workspace_zoom.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_zoom_strings.dart';

void main() {
  test('focal-point zoom preserves the inspected scene coordinate', () {
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);
    controller.updateViewportSize(const Size(1200, 800));

    const focalPoint = Offset(860, 530);
    final before = controller.transformationController.toScene(focalPoint);
    controller.setScaleAt(2, focalPoint);
    final after = controller.transformationController.toScene(focalPoint);

    expect(controller.currentScale, 2);
    expect(after.dx, closeTo(before.dx, .0001));
    expect(after.dy, closeTo(before.dy, .0001));
  });

  test('zoom controller clamps, resets and re-clamps after a resize', () {
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);
    controller.updateViewportSize(const Size(1000, 700));

    controller.setScaleAt(99, const Offset(1000, 700));
    expect(controller.currentScale, 4);
    expect(
      controller.transformationController.value.getTranslation().x,
      inInclusiveRange(-3000, 0),
    );
    expect(
      controller.transformationController.value.getTranslation().y,
      inInclusiveRange(-2100, 0),
    );

    controller.updateViewportSize(const Size(600, 400));
    expect(
      controller.transformationController.value.getTranslation().x,
      inInclusiveRange(-1800, 0),
    );
    expect(
      controller.transformationController.value.getTranslation().y,
      inInclusiveRange(-1200, 0),
    );

    controller.reset();
    expect(controller.currentScale, 1);
    expect(controller.transformationController.value, Matrix4.identity());
  });

  testWidgets('desktop controls zoom, reset and stay outside route content', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 800));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/overview',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('yorks-workspace-zoom-controls')),
      findsOneWidget,
    );
    expect(find.text('Route content'), findsOneWidget);

    await tester.tap(
      find.byTooltip(YorksV1ZoomStrings.zoomIn.active(AppLanguage.english)),
    );
    await tester.pumpAndSettle();
    expect(controller.currentScale, greaterThan(1));

    await tester.tap(
      find.text(YorksV1ZoomStrings.resetZoom.active(AppLanguage.english)),
    );
    await tester.pumpAndSettle();
    expect(controller.currentScale, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route changes reset the workspace to 100 percent', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 800));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/overview',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();
    controller.setScale(2);
    await tester.pump();
    expect(controller.currentScale, 2);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/material-requests',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.currentScale, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet workspace keeps the fixed precision controls', (
    tester,
  ) async {
    _setViewport(tester, const Size(820, 900));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/overview',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('yorks-workspace-zoom-controls')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal form fields and dropdown menus remain interactive', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 800));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/inventory/import',
        child: const _FormRouteContent(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('zoom-test-text-field')));
    await tester.enterText(
      find.byKey(const ValueKey('zoom-test-text-field')),
      'AHU-100',
    );
    expect(find.text('AHU-100'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('zoom-test-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project BOQ').last);
    await tester.pumpAndSettle();
    expect(find.text('Project BOQ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard shortcuts and native pinch use the route viewport', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 800));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/overview',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.currentScale, greaterThan(1));

    controller.reset();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(520, 380),
        scrollDelta: Offset(0, -72),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.currentScale, greaterThan(1));

    controller.reset();
    await tester.pump();
    final firstPointer = await tester.startGesture(
      const Offset(160, 420),
      pointer: 1,
    );
    final secondPointer = await tester.startGesture(
      const Offset(260, 420),
      pointer: 2,
    );
    await tester.pump();
    await firstPointer.moveBy(const Offset(-55, 0));
    await secondPointer.moveBy(const Offset(55, 0));
    await tester.pump();
    await firstPointer.up();
    await secondPointer.up();
    await tester.pumpAndSettle();
    expect(controller.currentScale, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact routes retain their normal touch layout and scroll', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final controller = YorksWorkspaceZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ZoomTestApp(
        controller: controller,
        routeKey: '/yorks/overview',
        child: const _ScrollableRouteContent(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('yorks-workspace-zoom-controls')),
      findsNothing,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Last controlled action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ZoomTestApp extends StatelessWidget {
  const _ZoomTestApp({
    required this.controller,
    required this.routeKey,
    required this.child,
  });

  final YorksWorkspaceZoomController controller;
  final String routeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: YorksWorkspaceZoomViewport(
        controller: controller,
        routeKey: routeKey,
        language: AppLanguage.english,
        child: child,
      ),
    ),
  );
}

class _ScrollableRouteContent extends StatelessWidget {
  const _ScrollableRouteContent();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('zoom-test-scrollable'),
    padding: const EdgeInsets.all(24),
    children: const [
      Text('Route content'),
      SizedBox(height: 1000),
      Text('Last controlled action'),
    ],
  );
}

class _FormRouteContent extends StatelessWidget {
  const _FormRouteContent();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      TextFormField(
        key: const ValueKey('zoom-test-text-field'),
        decoration: const InputDecoration(labelText: 'Item description'),
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        key: const ValueKey('zoom-test-dropdown'),
        initialValue: 'Building BOQ',
        items: const [
          DropdownMenuItem(value: 'Building BOQ', child: Text('Building BOQ')),
          DropdownMenuItem(value: 'Project BOQ', child: Text('Project BOQ')),
        ],
        onChanged: (_) {},
      ),
    ],
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
