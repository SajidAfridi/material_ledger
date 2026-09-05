import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_about_strings.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/screens/about_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(360, 800), const Size(1366, 900)]) {
    testWidgets('About is accurate and responsive at ${size.width}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'selected_language': 'en'});
      final preferences = await SharedPreferences.getInstance();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const MaterialApp(home: AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(YorksAboutStrings.heroTitle.primary), findsOneWidget);
      expect(
        find.text(YorksAboutStrings.projectsTitle.primary),
        findsOneWidget,
      );
      expect(
        find.text(YorksAboutStrings.workforceTitle.primary),
        findsOneWidget,
      );
      expect(
        find.text(YorksAboutStrings.accountsTitle.primary),
        findsOneWidget,
      );
      expect(
        find.text(YorksAboutStrings.currencyValue.primary),
        findsOneWidget,
      );
      expect(find.textContaining('THE ARCHITECTURAL LEDGER'), findsNothing);
      expect(find.textContaining('4 Currencies'), findsNothing);
      expect(find.textContaining('April 2026'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AboutScreen),
        matchesGoldenFile(
          'goldens/profile_p06/about_${size.width.toInt()}.png',
        ),
      );
    });
  }

  testWidgets('About follows the selected RTL language', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_language': 'ar'});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: AppLanguage.arabic.isRtl
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          ),
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(YorksAboutStrings.heroTitle.ar), findsOneWidget);
    expect(find.text(YorksAboutStrings.projectsTitle.ar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
