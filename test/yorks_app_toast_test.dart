import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/yorks_app_toast.dart';

void main() {
  setUpAll(() async {
    final textFont = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final iconBytes = await File(
      '${_flutterCacheDirectory().path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconFont = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await Future.wait([textFont.load(), iconFont.load()]);
  });

  for (final evidence in <({String suffix, Size size})>[
    (suffix: 'desktop', size: const Size(1366, 768)),
    (suffix: 'mobile', size: const Size(360, 800)),
  ]) {
    testWidgets('toast renders over an active dialog — ${evidence.suffix}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        YorksAppToast.dismiss();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const _ToastHarness());
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Show notice'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Inventory item updated'), findsOneWidget);
      expect(find.text('SAR-500 · Supply Air Register'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/app_toast_${evidence.suffix}.png'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Inventory item updated'), findsNothing);
    });
  }

  for (final evidence in <({String suffix, Size size})>[
    (suffix: 'desktop', size: const Size(1366, 768)),
    (suffix: 'mobile', size: const Size(360, 720)),
  ]) {
    testWidgets('notification toast is responsive — ${evidence.suffix}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        YorksAppToast.dismiss();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const _NotificationToastHarness());
      await tester.tap(find.text('Show alert'));
      await tester.pump();

      expect(find.text('You were mentioned'), findsOneWidget);
      expect(find.text('VIEW DETAILS'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/notification_toast_${evidence.suffix}.png',
        ),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
    });
  }
}

class _ToastHarness extends StatelessWidget {
  const _ToastHarness();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFEEF3F8),
        body: Center(
          child: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Edit Inventory Item'),
                content: const Text('Metadata is saved after confirmation.'),
                actions: [
                  TextButton(
                    onPressed: () => YorksAppToast.show(
                      dialogContext,
                      title: 'Inventory item updated',
                      message: 'SAR-500 · Supply Air Register',
                      tone: YorksAppToastTone.success,
                    ),
                    child: const Text('Show notice'),
                  ),
                ],
              ),
            ),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
}

class _NotificationToastHarness extends StatelessWidget {
  const _NotificationToastHarness();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFEEF3F8),
        body: Center(
          child: FilledButton(
            onPressed: () => YorksAppToast.show(
              context,
              title: 'You were mentioned',
              message:
                  'A teammate mentioned you in a material request comment.',
              icon: Icons.notifications_active_rounded,
              actionLabel: 'VIEW DETAILS',
              onAction: () {},
              dismissible: true,
              maxWidth: 560,
              duration: const Duration(seconds: 6),
            ),
            child: const Text('Show alert'),
          ),
        ),
      ),
    ),
  );
}

Directory _flutterCacheDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 8; level++) {
    if (directory.path.endsWith('${Platform.pathSeparator}cache')) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate the Flutter cache from the test runner');
}
