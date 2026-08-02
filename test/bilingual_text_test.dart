import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/widgets/yorks_v1_active_text.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_strings.dart';

void main() {
  testWidgets('shows only the configured language for each label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: YorksV1ActiveText(
            copy: _projects,
            language: AppLanguage.english,
          ),
        ),
      ),
    );

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('المشاريع'), findsNothing);
  });

  testWidgets(
    'uses the selected non-English translation without English copy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YorksV1ActiveText(
              copy: _projects,
              language: AppLanguage.arabic,
            ),
          ),
        ),
      );

      expect(find.text('Projects'), findsNothing);
      expect(find.text('المشاريع'), findsOneWidget);
    },
  );
}

const _projects = TranslatableString(
  en: 'Projects',
  ar: 'المشاريع',
  ur: 'منصوبے',
  hi: 'परियोजनाएं',
);
