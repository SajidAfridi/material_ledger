import 'app_strings.dart';

/// Device-local setup discovery, separate from committed project lifecycle copy.
abstract final class YorksV1ProjectLocalDraftStrings {
  static const title = TranslatableString(
    en: 'Saved project setup',
    ar: 'إعداد مشروع محفوظ',
    ur: 'محفوظ پراجیکٹ سیٹ اپ',
    hi: 'सहेजा गया प्रोजेक्ट सेटअप',
  );
  static const resume = TranslatableString(
    en: 'Resume setup',
    ar: 'متابعة الإعداد',
    ur: 'سیٹ اپ جاری رکھیں',
    hi: 'सेटअप जारी रखें',
  );
  static const deviceOnly = TranslatableString(
    en: 'Continue the setup saved on this device.',
    ar: 'تابع الإعداد المحفوظ على هذا الجهاز.',
    ur: 'اس ڈیوائس پر محفوظ سیٹ اپ جاری رکھیں۔',
    hi: 'इस डिवाइस पर सहेजा गया सेटअप जारी रखें।',
  );
  static const currentStep = TranslatableString(
    en: 'Current step',
    ar: 'الخطوة الحالية',
    ur: 'موجودہ مرحلہ',
    hi: 'वर्तमान चरण',
  );
  static const lastSaved = TranslatableString(
    en: 'Last saved',
    ar: 'آخر حفظ',
    ur: 'آخری بار محفوظ',
    hi: 'अंतिम बार सहेजा गया',
  );
  static const recoveryTitle = TranslatableString(
    en: 'Saved setup needs review',
    ar: 'يحتاج الإعداد المحفوظ إلى المراجعة',
    ur: 'محفوظ سیٹ اپ کا جائزہ ضروری ہے',
    hi: 'सहेजे गए सेटअप की समीक्षा आवश्यक है',
  );
  static const unavailable = TranslatableString(
    en: 'Local setup could not be checked. Open setup to review recovery.',
    ar: 'تعذر التحقق من الإعداد المحلي. افتح الإعداد لمراجعة الاستعادة.',
    ur: 'مقامی سیٹ اپ چیک نہیں ہو سکا۔ بحالی کا جائزہ لینے کے لیے سیٹ اپ کھولیں۔',
    hi: 'स्थानीय सेटअप की जाँच नहीं हो सकी। पुनर्प्राप्ति की समीक्षा के लिए सेटअप खोलें।',
  );
  static const unavailableTitle = TranslatableString(
    en: 'Local setup unavailable',
    ar: 'الإعداد المحلي غير متاح',
    ur: 'مقامی سیٹ اپ دستیاب نہیں',
    hi: 'स्थानीय सेटअप उपलब्ध नहीं',
  );
}
