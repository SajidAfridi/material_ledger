// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/app/app.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/services/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App launches and shows splash screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appVersionProvider.overrideWithValue(
            const AppVersionInfo(version: '1.0.0', build: 1),
          ),
        ],
        child: const MaterialLedgerApp(),
      ),
    );

    // Pump a single frame (not pumpAndSettle, since splash has animations)
    await tester.pump();

    // Verify splash/onboarding is shown (GodownPro branding).
    expect(find.textContaining('GodownPro'), findsWidgets);

    // Advance past all splash timers to avoid pending timer assertion
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
