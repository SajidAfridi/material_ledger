import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/app/yorks_localizations.dart';

void main() {
  test(
    'Yorks loads native framework copy for exactly its four languages',
    () async {
      const materialDelegate = YorksMaterialLocalizationsDelegate();
      const widgetsDelegate = YorksWidgetsLocalizationsDelegate();
      const cupertinoDelegate = YorksCupertinoLocalizationsDelegate();

      for (final locale in yorksSupportedLocales) {
        expect(materialDelegate.isSupported(locale), isTrue);
        expect(widgetsDelegate.isSupported(locale), isTrue);
        expect(cupertinoDelegate.isSupported(locale), isTrue);

        final material = await materialDelegate.load(locale);
        final widgets = await widgetsDelegate.load(locale);
        final cupertino = await cupertinoDelegate.load(locale);
        expect(material.backButtonTooltip, isNotEmpty);
        expect(
          widgets.textDirection,
          locale.languageCode == 'ar' || locale.languageCode == 'ur'
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        expect(cupertino.backButtonLabel, isNotEmpty);
      }

      expect(materialDelegate.isSupported(const Locale('fr')), isFalse);
    },
  );
}
