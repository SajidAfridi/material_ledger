import 'package:flutter/widgets.dart';

/// Copy for the simplified rental workspace controls, keyed independently of
/// stored property types, contract states and controlled workbook headings.
abstract final class RentalWorkspaceStrings {
  static String text(BuildContext context, String key) {
    final values = _copy[key]!;
    return values[Localizations.localeOf(context).languageCode] ??
        values['en']!;
  }

  static const _copy = {
    'title': {
      'en': 'Rental Properties',
      'ar': 'العقارات المؤجرة',
      'ur': 'کرائے کی جائیدادیں',
      'hi': 'किराये की संपत्तियाँ',
    },
    'refresh': {
      'en': 'Refresh rental register',
      'ar': 'تحديث سجل الإيجارات',
      'ur': 'کرایہ رجسٹر تازہ کریں',
      'hi': 'किराया रजिस्टर रीफ़्रेश करें',
    },
    'import': {
      'en': 'Import Excel',
      'ar': 'استيراد Excel',
      'ur': 'Excel درآمد کریں',
      'hi': 'Excel आयात करें',
    },
    'template': {
      'en': 'Download import format',
      'ar': 'تنزيل قالب الاستيراد',
      'ur': 'درآمد کا نمونہ ڈاؤن لوڈ کریں',
      'hi': 'आयात टेम्पलेट डाउनलोड करें',
    },
    'export': {
      'en': 'Export rental registers',
      'ar': 'تصدير سجلات الإيجار',
      'ur': 'کرایہ رجسٹر برآمد کریں',
      'hi': 'किराया रजिस्टर निर्यात करें',
    },
    'add': {
      'en': 'Add property',
      'ar': 'إضافة عقار',
      'ur': 'جائیداد شامل کریں',
      'hi': 'संपत्ति जोड़ें',
    },
    'overview': {
      'en': 'Overview',
      'ar': 'نظرة عامة',
      'ur': 'جائزہ',
      'hi': 'अवलोकन',
    },
    'properties': {
      'en': 'Property register',
      'ar': 'سجل العقارات',
      'ur': 'جائیداد رجسٹر',
      'hi': 'संपत्ति रजिस्टर',
    },
    'payments': {
      'en': 'Payments',
      'ar': 'الدفعات',
      'ur': 'ادائیگیاں',
      'hi': 'भुगतान',
    },
    'cheques': {
      'en': 'CDC / PDC',
      'ar': 'شيكات حالية / مؤجلة',
      'ur': 'CDC / PDC',
      'hi': 'CDC / PDC',
    },
    'expiry': {
      'en': 'Lease expiry',
      'ar': 'انتهاء الإيجار',
      'ur': 'لیز کی میعاد',
      'hi': 'लीज़ की समाप्ति',
    },
    'emptyTitle': {
      'en': 'Add your first rental property',
      'ar': 'أضف أول عقار مؤجر',
      'ur': 'اپنی پہلی کرائے کی جائیداد شامل کریں',
      'hi': 'अपनी पहली किराये की संपत्ति जोड़ें',
    },
    'emptyBody': {
      'en':
          'Add a property or import your Excel workbook. Then manage its lease, rent and payments here.',
      'ar': 'أضف عقاراً أو استورد ملف Excel، ثم تابع عقد الإيجار والدفعات هنا.',
      'ur':
          'جائیداد شامل کریں یا Excel فائل درآمد کریں۔ پھر یہاں لیز، کرایہ اور ادائیگیوں کا انتظام کریں۔',
      'hi':
          'संपत्ति जोड़ें या Excel फ़ाइल आयात करें। फिर यहाँ लीज़, किराया और भुगतान प्रबंधित करें।',
    },
  };
}
