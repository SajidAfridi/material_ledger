import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Flutter's public delegates load translation factories for every supported
// language. Yorks deliberately supports exactly four languages, so loading
// only their generated bundles keeps the first web download bounded while
// retaining native Material, Widgets and Cupertino semantics for each one.
// ignore: implementation_imports
import 'package:flutter_localizations/src/utils/date_localizations.dart'
    as date_localizations;
import 'package:intl/intl.dart' as intl;

const yorksLocalizationDelegates = <LocalizationsDelegate<dynamic>>[
  YorksMaterialLocalizationsDelegate(),
  YorksWidgetsLocalizationsDelegate(),
  YorksCupertinoLocalizationsDelegate(),
];

const yorksSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
  Locale('ur'),
  Locale('hi'),
];

bool _isYorksLocale(Locale locale) =>
    const {'en', 'ar', 'ur', 'hi'}.contains(locale.languageCode);

String _localeName(Locale locale) =>
    intl.Intl.canonicalizedLocale(locale.toString());

class YorksMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const YorksMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isYorksLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    date_localizations.loadDateIntlDataIfNotLoaded();
    final name = _localeName(locale);
    final formatLocale = intl.DateFormat.localeExists(name)
        ? name
        : intl.DateFormat.localeExists(locale.languageCode)
        ? locale.languageCode
        : null;
    final fullYearFormat = intl.DateFormat.y(formatLocale);
    final compactDateFormat = intl.DateFormat.yMd(formatLocale);
    final shortDateFormat = intl.DateFormat.yMMMd(formatLocale);
    final mediumDateFormat = intl.DateFormat.MMMEd(formatLocale);
    final longDateFormat = intl.DateFormat.yMMMMEEEEd(formatLocale);
    final yearMonthFormat = intl.DateFormat.yMMMM(formatLocale);
    final shortMonthDayFormat = intl.DateFormat.MMMd(formatLocale);
    final decimalFormat = intl.NumberFormat.decimalPattern(formatLocale);
    final twoDigitZeroPaddedFormat = intl.NumberFormat('00', formatLocale);

    MaterialLocalizations translation;
    switch (locale.languageCode) {
      case 'ar':
        translation = MaterialLocalizationAr(
          localeName: name,
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        );
      case 'ur':
        translation = MaterialLocalizationUr(
          localeName: name,
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        );
      case 'hi':
        translation = MaterialLocalizationHi(
          localeName: name,
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        );
      case 'en':
      default:
        translation = MaterialLocalizationEn(
          localeName: name,
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        );
    }
    return SynchronousFuture(translation);
  }

  @override
  bool shouldReload(YorksMaterialLocalizationsDelegate old) => false;
}

class YorksWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const YorksWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isYorksLocale(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final WidgetsLocalizations translation = switch (locale.languageCode) {
      'ar' => const WidgetsLocalizationAr(),
      'ur' => const WidgetsLocalizationUr(),
      'hi' => const WidgetsLocalizationHi(),
      _ => const WidgetsLocalizationEn(),
    };
    return SynchronousFuture(translation);
  }

  @override
  bool shouldReload(YorksWidgetsLocalizationsDelegate old) => false;
}

class YorksCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const YorksCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isYorksLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    date_localizations.loadDateIntlDataIfNotLoaded();
    final name = _localeName(locale);
    final formatLocale = intl.DateFormat.localeExists(name)
        ? name
        : intl.DateFormat.localeExists(locale.languageCode)
        ? locale.languageCode
        : null;
    final fullYearFormat = intl.DateFormat.y(formatLocale);
    final dayFormat = intl.DateFormat.d(formatLocale);
    final weekdayFormat = intl.DateFormat.E(formatLocale);
    final mediumDateFormat = intl.DateFormat.MMMEd(formatLocale);
    final singleDigitHourFormat = intl.DateFormat('HH', formatLocale);
    final singleDigitMinuteFormat = intl.DateFormat.m(formatLocale);
    final doubleDigitMinuteFormat = intl.DateFormat('mm', formatLocale);
    final singleDigitSecondFormat = intl.DateFormat.s(formatLocale);
    final decimalFormat = intl.NumberFormat.decimalPattern(formatLocale);

    CupertinoLocalizations translation;
    switch (locale.languageCode) {
      case 'ar':
        translation = CupertinoLocalizationAr(
          localeName: name,
          fullYearFormat: fullYearFormat,
          dayFormat: dayFormat,
          weekdayFormat: weekdayFormat,
          mediumDateFormat: mediumDateFormat,
          singleDigitHourFormat: singleDigitHourFormat,
          singleDigitMinuteFormat: singleDigitMinuteFormat,
          doubleDigitMinuteFormat: doubleDigitMinuteFormat,
          singleDigitSecondFormat: singleDigitSecondFormat,
          decimalFormat: decimalFormat,
        );
      case 'ur':
        translation = CupertinoLocalizationUr(
          localeName: name,
          fullYearFormat: fullYearFormat,
          dayFormat: dayFormat,
          weekdayFormat: weekdayFormat,
          mediumDateFormat: mediumDateFormat,
          singleDigitHourFormat: singleDigitHourFormat,
          singleDigitMinuteFormat: singleDigitMinuteFormat,
          doubleDigitMinuteFormat: doubleDigitMinuteFormat,
          singleDigitSecondFormat: singleDigitSecondFormat,
          decimalFormat: decimalFormat,
        );
      case 'hi':
        translation = CupertinoLocalizationHi(
          localeName: name,
          fullYearFormat: fullYearFormat,
          dayFormat: dayFormat,
          weekdayFormat: weekdayFormat,
          mediumDateFormat: mediumDateFormat,
          singleDigitHourFormat: singleDigitHourFormat,
          singleDigitMinuteFormat: singleDigitMinuteFormat,
          doubleDigitMinuteFormat: doubleDigitMinuteFormat,
          singleDigitSecondFormat: singleDigitSecondFormat,
          decimalFormat: decimalFormat,
        );
      case 'en':
      default:
        translation = CupertinoLocalizationEn(
          localeName: name,
          fullYearFormat: fullYearFormat,
          dayFormat: dayFormat,
          weekdayFormat: weekdayFormat,
          mediumDateFormat: mediumDateFormat,
          singleDigitHourFormat: singleDigitHourFormat,
          singleDigitMinuteFormat: singleDigitMinuteFormat,
          doubleDigitMinuteFormat: doubleDigitMinuteFormat,
          singleDigitSecondFormat: singleDigitSecondFormat,
          decimalFormat: decimalFormat,
        );
    }
    return SynchronousFuture(translation);
  }

  @override
  bool shouldReload(YorksCupertinoLocalizationsDelegate old) => false;
}
