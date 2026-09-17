import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/widgets/yorks_v1_submission_recovery_panel.dart';
import 'package:material_ledger/shared/models/app_language.dart';

void main() {
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    for (
      var level = 0;
      level < 8 && !directory.path.endsWith('/cache');
      level++
    ) {
      directory = directory.parent;
    }
    final iconBytes = await File(
      '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    await (FontLoader(
      'NexusSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf')))
        .load();
  });

  for (final width in [1366.0, 360.0]) {
    for (final language in [AppLanguage.english, AppLanguage.arabic]) {
      testWidgets('recovery at $width ${language.code}', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var checks = 0;
        var retries = 0;
        Future<void> pump({bool canRetry = false, bool checking = false}) =>
            tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                debugShowCheckedModeBanner: false,
                home: Directionality(
                  textDirection: language == AppLanguage.arabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 800),
                      textScaler: const TextScaler.linear(1.5),
                    ),
                    child: Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 900,
                            child: YorksV1SubmissionRecoveryPanel(
                              language: language,
                              checking: checking,
                              canRetry: canRetry,
                              onCheck: () => checks++,
                              onRetry: () => retries++,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
        await pump();
        expect(
          find.byKey(const ValueKey('mr-retry-same-submission')),
          findsNothing,
        );
        final check = find.byKey(const ValueKey('mr-check-submission'));
        expect(tester.getSize(check).height, greaterThanOrEqualTo(44));
        await tester.tap(check);
        expect(checks, 1);
        expect(retries, 0);
        await pump(canRetry: true);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/mr_recovery_${width.toInt()}_${language.code}.png',
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('mr-retry-same-submission')),
        );
        expect(retries, 1);
        await pump(canRetry: true, checking: true);
        await tester.tap(check);
        await tester.tap(
          find.byKey(const ValueKey('mr-retry-same-submission')),
        );
        expect(checks, 1);
        expect(retries, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
