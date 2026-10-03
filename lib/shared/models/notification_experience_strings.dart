import 'app_strings.dart';
import 'app_language.dart';

abstract final class NotificationExperienceStrings {
  static const mainSiteAlerts = TranslatableString(
    en: 'Device alerts are available on the main Yorks site. Your notification history remains available here.',
    ar: 'تنبيهات الجهاز متاحة على موقع يوركس الرئيسي. يبقى سجل إشعاراتك متاحًا هنا.',
    ur: 'ڈیوائس الرٹس یورکس کی مرکزی ویب سائٹ پر دستیاب ہیں۔ آپ کی نوٹیفکیشن ہسٹری یہاں دستیاب رہے گی۔',
    hi: 'डिवाइस अलर्ट मुख्य यॉर्क्स साइट पर उपलब्ध हैं। आपकी सूचना सूची यहाँ उपलब्ध रहेगी।',
  );
  static String updateCount(int count, AppLanguage language) =>
      TranslatableString(
        en: '$count new updates. Open to review them.',
        ar: '$count تحديثات جديدة. افتح لمراجعتها.',
        ur: '$count نئی اپ ڈیٹس۔ دیکھنے کے لیے کھولیں۔',
        hi: '$count नए अपडेट। समीक्षा के लिए खोलें।',
      ).active(language);

  static String mixedUpdateCount(
    int workflowCount,
    int chatCount,
    AppLanguage language,
  ) => TranslatableString(
    en: 'Workflow updates: $workflowCount · Team Chat updates: $chatCount.',
    ar: 'تحديثات سير العمل: $workflowCount · تحديثات محادثة الفريق: $chatCount.',
    ur: 'ورک فلو اپ ڈیٹس: $workflowCount · ٹیم چیٹ اپ ڈیٹس: $chatCount۔',
    hi: 'कार्यप्रवाह अपडेट: $workflowCount · टीम चैट अपडेट: $chatCount।',
  ).active(language);

  static const search = TranslatableString(
    en: 'Search event or request reference',
    ar: 'ابحث عن الحدث أو مرجع الطلب',
    ur: 'واقعہ یا درخواست حوالہ تلاش کریں',
    hi: 'घटना या अनुरोध संदर्भ खोजें',
  );
  static const unread = TranslatableString(
    en: 'Unread',
    ar: 'غير مقروء',
    ur: 'ان پڑھا',
    hi: 'अपठित',
  );
  static const read = TranslatableString(
    en: 'Read',
    ar: 'مقروء',
    ur: 'پڑھا ہوا',
    hi: 'पठित',
  );
  static const updatesWaiting = TranslatableString(
    en: 'New updates are waiting',
    ar: 'توجد تحديثات جديدة',
    ur: 'نئی اپ ڈیٹس موجود ہیں',
    hi: 'नए अपडेट उपलब्ध हैं',
  );
  static const loadMore = TranslatableString(
    en: 'Load earlier notifications',
    ar: 'تحميل الإشعارات الأقدم',
    ur: 'پرانے نوٹیفکیشن لوڈ کریں',
    hi: 'पुरानी सूचनाएँ लोड करें',
  );
  static const stale = TranslatableString(
    en: 'Could not refresh. Showing the last available notifications.',
    ar: 'تعذر التحديث. يتم عرض آخر إشعارات متاحة.',
    ur: 'تازہ نہیں ہو سکا۔ آخری دستیاب اطلاعات دکھائی جا رہی ہیں۔',
    hi: 'रीफ्रेश नहीं हुआ। अंतिम उपलब्ध सूचनाएँ दिखाई जा रही हैं।',
  );
  static const readFailed = TranslatableString(
    en: 'Could not mark as read. Please try again.',
    ar: 'تعذر وضع علامة مقروء. حاول مرة أخرى.',
    ur: 'پڑھا ہوا نشان نہیں لگ سکا۔ دوبارہ کوشش کریں۔',
    hi: 'पढ़ा हुआ चिह्नित नहीं हुआ। फिर कोशिश करें।',
  );
  static const noUnread = TranslatableString(
    en: 'No unread notifications',
    ar: 'لا توجد إشعارات غير مقروءة',
    ur: 'کوئی ان پڑھی اطلاع نہیں',
    hi: 'कोई अपठित सूचना नहीं',
  );
  static const noUrgent = TranslatableString(
    en: 'No urgent notifications',
    ar: 'لا توجد إشعارات عاجلة',
    ur: 'کوئی فوری اطلاع نہیں',
    hi: 'कोई तत्काल सूचना नहीं',
  );
  static const servicePaused = TranslatableString(
    en: 'Device pop-ups are temporarily paused by the service. Your notification history remains available here.',
    ar: 'أوقفت الخدمة التنبيهات مؤقتاً. يبقى سجل الإشعارات متاحاً هنا.',
    ur: 'سروس نے عارضی طور پر پاپ اپ روک دیے ہیں۔ اطلاعات کی تاریخ یہاں دستیاب ہے۔',
    hi: 'सेवा ने पॉप-अप अस्थायी रूप से रोके हैं। सूचना इतिहास यहाँ उपलब्ध है।',
  );
  static const installWebApp = TranslatableString(
    en: 'On iPhone or iPad, add Yorks to your Home Screen, then enable alerts from the installed app. In other browsers, check notification and system settings.',
    ar: 'على iPhone أو iPad، أضف يوركس إلى الشاشة الرئيسية ثم فعّل التنبيهات من التطبيق المثبت. في المتصفحات الأخرى، تحقق من إعدادات الإشعارات والنظام.',
    ur: 'آئی فون یا آئی پیڈ پر یورکس کو ہوم اسکرین پر شامل کریں، پھر نصب شدہ ایپ سے الرٹس فعال کریں۔ دیگر براؤزرز میں اطلاع اور سسٹم کی ترتیبات دیکھیں۔',
    hi: 'iPhone या iPad पर Yorks को होम स्क्रीन पर जोड़ें, फिर इंस्टॉल ऐप से अलर्ट चालू करें। अन्य ब्राउज़र में सूचना और सिस्टम सेटिंग जाँचें।',
  );
}
