import 'app_strings.dart';

abstract final class YorksV1AuditInvestigationStrings {
  static const lastSuccessful = TranslatableString(
    en: 'Last successful filters',
    ar: 'آخر مرشحات ناجحة',
    ur: 'آخری کامیاب فلٹرز',
    hi: 'अंतिम सफल फ़िल्टर',
  );
  static const unclassified = TranslatableString(
    en: 'Unclassified',
    ar: 'غير مصنف',
    ur: 'غیر درجہ بند',
    hi: 'अवर्गीकृत',
  );
  static TranslatableString fact(String key) => switch (key) {
    'state' => TranslatableString(
      en: 'State',
      ar: 'الحالة',
      ur: 'حالت',
      hi: 'स्थिति',
    ),
    'decision' => TranslatableString(
      en: 'Decision',
      ar: 'القرار',
      ur: 'فیصلہ',
      hi: 'निर्णय',
    ),
    'action' => TranslatableString(
      en: 'Action',
      ar: 'الإجراء',
      ur: 'کارروائی',
      hi: 'कार्रवाई',
    ),
    'line_count' => TranslatableString(
      en: 'Line count',
      ar: 'عدد البنود',
      ur: 'آئٹم تعداد',
      hi: 'पंक्ति संख्या',
    ),
    'record_version' => TranslatableString(
      en: 'Record version',
      ar: 'إصدار السجل',
      ur: 'ریکارڈ ورژن',
      hi: 'रिकॉर्ड संस्करण',
    ),
    'snapshot_source' => TranslatableString(
      en: 'Snapshot source',
      ar: 'مصدر اللقطة',
      ur: 'اسنیپ شاٹ ماخذ',
      hi: 'स्नैपशॉट स्रोत',
    ),
    'quantity_delta' => TranslatableString(
      en: 'Quantity change',
      ar: 'تغير الكمية',
      ur: 'مقدار کی تبدیلی',
      hi: 'मात्रा में बदलाव',
    ),
    'created_count' => TranslatableString(
      en: 'Created count',
      ar: 'عدد السجلات المنشأة',
      ur: 'بنائے گئے ریکارڈ',
      hi: 'बनाए गए रिकॉर्ड',
    ),
    'is_active' => TranslatableString(
      en: 'Active',
      ar: 'نشط',
      ur: 'فعال',
      hi: 'सक्रिय',
    ),
    'request_clarification_revision' => TranslatableString(
      en: 'Clarification revision',
      ar: 'مراجعة التوضيح',
      ur: 'وضاحت ورژن',
      hi: 'स्पष्टीकरण संशोधन',
    ),
    'approved_clarification_revision' => TranslatableString(
      en: 'Approved clarification revision',
      ar: 'مراجعة التوضيح المعتمدة',
      ur: 'منظور شدہ وضاحت ورژن',
      hi: 'स्वीकृत स्पष्टीकरण संशोधन',
    ),
    _ => facts,
  };
  static const matching = TranslatableString(
    en: 'Matching events',
    ar: 'الأحداث المطابقة',
    ur: 'مطابق واقعات',
    hi: 'मिलते हुए इवेंट',
  );
  static const selectedScope = TranslatableString(
    en: 'Selected filters and period',
    ar: 'المرشحات والفترة المحددة',
    ur: 'منتخب فلٹرز اور مدت',
    hi: 'चुने गए फ़िल्टर और अवधि',
  );
  static const filters = TranslatableString(
    en: 'Filters',
    ar: 'المرشحات',
    ur: 'فلٹرز',
    hi: 'फ़िल्टर',
  );
  static const clearAll = TranslatableString(
    en: 'Clear all',
    ar: 'مسح الكل',
    ur: 'سب صاف کریں',
    hi: 'सभी हटाएँ',
  );
  static const today = TranslatableString(
    en: 'Today',
    ar: 'اليوم',
    ur: 'آج',
    hi: 'आज',
  );
  static const customDates = TranslatableString(
    en: 'Custom dates',
    ar: 'تواريخ مخصصة',
    ur: 'اپنی تاریخیں',
    hi: 'कस्टम तिथियाँ',
  );
  static const updated = TranslatableString(
    en: 'Updated',
    ar: 'آخر تحديث',
    ur: 'تازہ کاری',
    hi: 'अपडेट',
  );
  static const stale = TranslatableString(
    en: 'Showing previously loaded results. Refresh before exporting.',
    ar: 'تظهر النتائج السابقة. حدّث قبل التصدير.',
    ur: 'پہلے لوڈ شدہ نتائج دکھائے جا رہے ہیں۔ برآمد سے پہلے تازہ کریں۔',
    hi: 'पहले लोड किए गए परिणाम। निर्यात से पहले रीफ़्रेश करें।',
  );
  static const denied = TranslatableString(
    en: 'Audit access is no longer available.',
    ar: 'لم يعد الوصول إلى التدقيق متاحًا.',
    ur: 'آڈٹ تک رسائی دستیاب نہیں رہی۔',
    hi: 'ऑडिट की पहुँच अब उपलब्ध नहीं है।',
  );
  static const copyPage = TranslatableString(
    en: 'Copy current page',
    ar: 'نسخ الصفحة الحالية',
    ur: 'موجودہ صفحہ کاپی کریں',
    hi: 'वर्तमान पृष्ठ कॉपी करें',
  );
  static const download = TranslatableString(
    en: 'Download filtered results',
    ar: 'تنزيل النتائج المصفاة',
    ur: 'فلٹر شدہ نتائج ڈاؤن لوڈ کریں',
    hi: 'फ़िल्टर किए परिणाम डाउनलोड करें',
  );
  static const exportFailed = TranslatableString(
    en: 'Export unavailable. Retry or narrow the range to 5,000 events or fewer.',
    ar: 'التصدير غير متاح. أعد المحاولة أو قلّل النطاق إلى ٥٠٠٠ حدث أو أقل.',
    ur: 'برآمد دستیاب نہیں۔ دوبارہ کوشش کریں یا حد ۵۰۰۰ واقعات تک کریں۔',
    hi: 'निर्यात उपलब्ध नहीं। पुनः प्रयास करें या सीमा 5,000 इवेंट तक घटाएँ।',
  );
  static const exportSaved = TranslatableString(
    en: 'Audit export saved',
    ar: 'تم حفظ تصدير التدقيق',
    ur: 'آڈٹ برآمد محفوظ ہوگئی',
    hi: 'ऑडिट निर्यात सहेजा गया',
  );
  static const details = TranslatableString(
    en: 'Event details',
    ar: 'تفاصيل الحدث',
    ur: 'واقعے کی تفصیلات',
    hi: 'इवेंट विवरण',
  );
  static const openRecord = TranslatableString(
    en: 'Open record',
    ar: 'فتح السجل',
    ur: 'ریکارڈ کھولیں',
    hi: 'रिकॉर्ड खोलें',
  );
  static const timeline = TranslatableString(
    en: 'Same-record history',
    ar: 'سجل الكيان نفسه',
    ur: 'اسی ریکارڈ کی تاریخ',
    hi: 'इसी रिकॉर्ड का इतिहास',
  );
  static const noFacts = TranslatableString(
    en: 'Change details were not recorded for this event.',
    ar: 'لم تُسجل تفاصيل التغيير لهذا الحدث.',
    ur: 'اس واقعے کی تبدیلی کی تفصیلات درج نہیں ہیں۔',
    hi: 'इस इवेंट के बदलाव का विवरण दर्ज नहीं किया गया।',
  );
  static const before = TranslatableString(
    en: 'Before',
    ar: 'قبل',
    ur: 'پہلے',
    hi: 'पहले',
  );
  static const after = TranslatableString(
    en: 'After',
    ar: 'بعد',
    ur: 'بعد',
    hi: 'बाद',
  );
  static const eventId = TranslatableString(
    en: 'Event ID',
    ar: 'معرّف الحدث',
    ur: 'واقعہ شناخت',
    hi: 'इवेंट आईडी',
  );
  static const actor = TranslatableString(
    en: 'Actor',
    ar: 'المنفذ',
    ur: 'صارف',
    hi: 'कर्ता',
  );
  static const project = TranslatableString(
    en: 'Project',
    ar: 'المشروع',
    ur: 'پروجیکٹ',
    hi: 'प्रोजेक्ट',
  );
  static const scope = TranslatableString(
    en: 'Scope',
    ar: 'النطاق',
    ur: 'دائرہ',
    hi: 'दायरा',
  );
  static const company = TranslatableString(
    en: 'Company use',
    ar: 'استخدام الشركة',
    ur: 'کمپنی استعمال',
    hi: 'कंपनी उपयोग',
  );
  static const organization = TranslatableString(
    en: 'Organization',
    ar: 'المؤسسة',
    ur: 'ادارہ',
    hi: 'संगठन',
  );
  static const eventType = TranslatableString(
    en: 'Event type',
    ar: 'نوع الحدث',
    ur: 'واقعے کی قسم',
    hi: 'इवेंट प्रकार',
  );
  static const severity = TranslatableString(
    en: 'Classification',
    ar: 'التصنيف',
    ur: 'درجہ بندی',
    hi: 'वर्गीकरण',
  );
  static const normal = TranslatableString(
    en: 'Normal',
    ar: 'عادي',
    ur: 'عام',
    hi: 'सामान्य',
  );
  static const warning = TranslatableString(
    en: 'Warning',
    ar: 'تحذير',
    ur: 'انتباہ',
    hi: 'चेतावनी',
  );
  static const critical = TranslatableString(
    en: 'Critical',
    ar: 'حرج',
    ur: 'اہم',
    hi: 'गंभीर',
  );
  static const all = TranslatableString(
    en: 'All',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const apply = TranslatableString(
    en: 'Apply filters',
    ar: 'تطبيق المرشحات',
    ur: 'فلٹرز لگائیں',
    hi: 'फ़िल्टर लागू करें',
  );
  static const noEvidence = TranslatableString(
    en: 'No events to assess',
    ar: 'لا توجد أحداث للتقييم',
    ur: 'جانچنے کے لیے واقعات نہیں',
    hi: 'आकलन के लिए कोई इवेंट नहीं',
  );
  static const compact = TranslatableString(
    en: 'Compact rows',
    ar: 'صفوف مضغوطة',
    ur: 'مختصر قطاریں',
    hi: 'सघन पंक्तियाँ',
  );
  static const record = TranslatableString(
    en: 'Record / project',
    ar: 'السجل / المشروع',
    ur: 'ریکارڈ / پروجیکٹ',
    hi: 'रिकॉर्ड / प्रोजेक्ट',
  );
  static const facts = TranslatableString(
    en: 'Recorded facts',
    ar: 'الحقائق المسجلة',
    ur: 'درج حقائق',
    hi: 'दर्ज तथ्य',
  );
  static const reason = TranslatableString(
    en: 'Reason',
    ar: 'السبب',
    ur: 'وجہ',
    hi: 'कारण',
  );
  static const timezone = TranslatableString(
    en: 'Device timezone',
    ar: 'المنطقة الزمنية للجهاز',
    ur: 'آلہ کا ٹائم زون',
    hi: 'डिवाइस समय क्षेत्र',
  );
  static const copyId = TranslatableString(
    en: 'Copy event ID',
    ar: 'نسخ معرّف الحدث',
    ur: 'واقعہ شناخت کاپی کریں',
    hi: 'इवेंट आईडी कॉपी करें',
  );
  static const historyHint = TranslatableString(
    en: 'History uses the exact record identity across all recorded time.',
    ar: 'يستخدم السجل هوية الكيان الدقيقة عبر كل الوقت المسجل.',
    ur: 'تاریخ تمام وقت میں اسی ریکارڈ کی درست شناخت استعمال کرتی ہے۔',
    hi: 'इतिहास पूरे समय में इसी रिकॉर्ड की सटीक पहचान का उपयोग करता है।',
  );
  static const more = TranslatableString(
    en: 'Load more',
    ar: 'تحميل المزيد',
    ur: 'مزید لوڈ کریں',
    hi: 'और लोड करें',
  );
}
