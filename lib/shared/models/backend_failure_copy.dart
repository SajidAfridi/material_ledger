import 'app_strings.dart';

/// Copy for the pre-provider startup failure state. English is shown because
/// persisted language preferences are intentionally not opened after a rejected
/// backend configuration; translations remain defined for the shared catalog.
abstract final class BackendFailureCopy {
  static const title = TranslatableString(
    en: 'Yorks could not start securely.',
    ar: 'تعذر بدء تشغيل Yorks بأمان.',
    ur: 'Yorks محفوظ طریقے سے شروع نہیں ہو سکا۔',
    hi: 'Yorks सुरक्षित रूप से शुरू नहीं हो सका।',
  );

  static const body = TranslatableString(
    en: 'Ask the system administrator to check this deployment.',
    ar: 'اطلب من مسؤول النظام التحقق من هذا النشر.',
    ur: 'سسٹم ایڈمنسٹریٹر سے اس تعیناتی کو چیک کرنے کو کہیں۔',
    hi: 'सिस्टम एडमिनिस्ट्रेटर से इस डिप्लॉयमेंट की जाँच करने को कहें।',
  );
}
