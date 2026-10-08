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
    'schedule': {
      'en': 'Rent Schedule',
      'ar': 'جدول الإيجار',
      'ur': 'کرایہ شیڈول',
      'hi': 'किराया अनुसूची',
    },
    'documents': {
      'en': 'Documents',
      'ar': 'المستندات',
      'ur': 'دستاویزات',
      'hi': 'दस्तावेज़',
    },
    'activity': {
      'en': 'Activity',
      'ar': 'النشاط',
      'ur': 'سرگرمی',
      'hi': 'गतिविधि',
    },
    'edit': {
      'en': 'Edit property',
      'ar': 'تعديل العقار',
      'ur': 'جائیداد میں ترمیم',
      'hi': 'संपत्ति संपादित करें',
    },
    'archive': {
      'en': 'Archive',
      'ar': 'أرشفة',
      'ur': 'محفوظات',
      'hi': 'संग्रह करें',
    },

    'saved': {
      'en': 'Rental property saved.',
      'ar': 'تم حفظ العقار.',
      'ur': 'جائیداد محفوظ ہو گئی۔',
      'hi': 'संपत्ति सहेज दी गई।',
    },
    'saving': {
      'en': 'Saving…',
      'ar': 'جارٍ الحفظ…',
      'ur': 'محفوظ ہو رہا ہے…',
      'hi': 'सहेजा जा रहा है…',
    },
    'retrySave': {
      'en': 'Confirm save',
      'ar': 'تأكيد الحفظ',
      'ur': 'محفوظ کرنے کی تصدیق',
      'hi': 'सहेजने की पुष्टि करें',
    },
    'create': {
      'en': 'Create property',
      'ar': 'إنشاء عقار',
      'ur': 'جائیداد بنائیں',
      'hi': 'संपत्ति बनाएँ',
    },
    'save': {
      'en': 'Save property',
      'ar': 'حفظ العقار',
      'ur': 'جائیداد محفوظ کریں',
      'hi': 'संपत्ति सहेजें',
    },
    'unconfirmed': {
      'en':
          'The save could not be confirmed. Your entries are kept here. Confirm save retries the same request safely before further changes.',
      'ar':
          'تعذر تأكيد الحفظ. بياناتك محفوظة هنا. أعد تأكيد الطلب نفسه بأمان قبل إجراء تغييرات أخرى.',
      'ur':
          'محفوظ ہونے کی تصدیق نہیں ہوئی۔ آپ کی معلومات یہاں موجود ہیں۔ مزید تبدیلی سے پہلے اسی درخواست کی دوبارہ تصدیق کریں۔',
      'hi':
          'सहेजने की पुष्टि नहीं हो सकी। आपकी जानकारी यहाँ रखी गई है। बदलाव से पहले उसी अनुरोध की सुरक्षित पुष्टि करें।',
    },
    'conflict': {
      'en':
          'This property changed since you opened it. Your entries are kept here. Close and reload the property before applying changes.',
      'ar':
          'تغير العقار منذ فتحه. بياناتك موجودة هنا. أغلق وأعد تحميل العقار قبل تطبيق التغييرات.',
      'ur':
          'کھولنے کے بعد جائیداد تبدیل ہوئی ہے۔ معلومات یہاں موجود ہیں۔ تبدیلی سے پہلے بند کر کے دوبارہ کھولیں۔',
      'hi':
          'खोलने के बाद संपत्ति बदल गई है। आपकी जानकारी यहाँ है। बदलाव से पहले बंद करके फिर लोड करें।',
    },
    'saveFailed': {
      'en':
          'The property was not saved. Your entries are kept here. Check the details and your connection, then try again.',
      'ar':
          'لم يتم حفظ العقار. بياناتك موجودة هنا. تحقق من التفاصيل والاتصال ثم حاول مجدداً.',
      'ur':
          'جائیداد محفوظ نہیں ہوئی۔ معلومات یہاں موجود ہیں۔ تفصیلات اور رابطہ دیکھ کر دوبارہ کوشش کریں۔',
      'hi':
          'संपत्ति सहेजी नहीं गई। जानकारी यहाँ है। विवरण और कनेक्शन जाँचकर फिर कोशिश करें।',
    },

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
