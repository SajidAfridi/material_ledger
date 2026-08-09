import 'app_strings.dart';

/// Centralized R38.3 warehouse copy. No operational warehouse surface owns
/// literal user-facing text, so locale expansion remains a data-only change.
abstract final class YorksV1InventoryStrings {
  static const warehouse = TranslatableString(
    en: 'Warehouse',
    ar: 'المستودع',
    ur: 'گودام',
    hi: 'वेयरहाउस',
  );
  static const subtitle = TranslatableString(
    en: 'Live stock, reservations and movement history',
    ar: 'المخزون المباشر والحجوزات وسجل الحركات',
    ur: 'لائیو اسٹاک، ریزرویشن اور حرکت کی تاریخ',
    hi: 'लाइव स्टॉक, आरक्षण और मूवमेंट इतिहास',
  );
  static const overview = TranslatableString(
    en: 'Overview',
    ar: 'نظرة عامة',
    ur: 'جائزہ',
    hi: 'अवलोकन',
  );
  static const items = TranslatableString(
    en: 'Items',
    ar: 'الأصناف',
    ur: 'آئٹمز',
    hi: 'आइटम',
  );
  static const movements = TranslatableString(
    en: 'Stock Movements',
    ar: 'حركات المخزون',
    ur: 'اسٹاک کی حرکات',
    hi: 'स्टॉक मूवमेंट',
  );
  static const reservations = TranslatableString(
    en: 'Reservations',
    ar: 'الحجوزات',
    ur: 'ریزرویشنز',
    hi: 'आरक्षण',
  );
  static const totalItems = TranslatableString(
    en: 'Total items',
    ar: 'إجمالي الأصناف',
    ur: 'کل آئٹمز',
    hi: 'कुल आइटम',
  );
  static const availableStock = TranslatableString(
    en: 'Available stock',
    ar: 'المخزون المتاح',
    ur: 'دستیاب اسٹاک',
    hi: 'उपलब्ध स्टॉक',
  );
  static const reservedStock = TranslatableString(
    en: 'Reserved stock',
    ar: 'المخزون المحجوز',
    ur: 'محفوظ اسٹاک',
    hi: 'आरक्षित स्टॉक',
  );
  static const needsAttention = TranslatableString(
    en: 'Needs attention',
    ar: 'يحتاج إلى انتباه',
    ur: 'توجہ درکار',
    hi: 'ध्यान आवश्यक',
  );
  static const stockFormula = TranslatableString(
    en: 'Available = On hand - Reserved',
    ar: 'المتاح = الموجود - المحجوز',
    ur: 'دستیاب = موجود - محفوظ',
    hi: 'उपलब्ध = ऑन हैंड - आरक्षित',
  );
  static const formulaHelp = TranslatableString(
    en: 'Reservations protect approved requests. Imports and adjustments always append a stock movement.',
    ar: 'تحمي الحجوزات الطلبات المعتمدة. تضيف عمليات الاستيراد والتعديل حركة مخزون دائماً.',
    ur: 'ریزرویشن منظور شدہ درخواستوں کو محفوظ رکھتے ہیں۔ درآمد اور ایڈجسٹمنٹ ہمیشہ اسٹاک موومنٹ شامل کرتے ہیں۔',
    hi: 'आरक्षण स्वीकृत अनुरोधों की रक्षा करते हैं। आयात और समायोजन हमेशा स्टॉक मूवमेंट जोड़ते हैं।',
  );
  static const quickTools = TranslatableString(
    en: 'Quick tools',
    ar: 'أدوات سريعة',
    ur: 'فوری ٹولز',
    hi: 'त्वरित टूल',
  );
  static const addReceive = TranslatableString(
    en: 'Add / Receive stock',
    ar: 'إضافة / استلام مخزون',
    ur: 'اسٹاک شامل / وصول کریں',
    hi: 'स्टॉक जोड़ें / प्राप्त करें',
  );
  static const addStock = TranslatableString(
    en: 'Add stock',
    ar: 'إضافة مخزون',
    ur: 'اسٹاک شامل کریں',
    hi: 'स्टॉक जोड़ें',
  );
  static const removeStock = TranslatableString(
    en: 'Remove stock',
    ar: 'خصم مخزون',
    ur: 'اسٹاک نکالیں',
    hi: 'स्टॉक हटाएं',
  );
  static const importInventory = TranslatableString(
    en: 'Import inventory',
    ar: 'استيراد المخزون',
    ur: 'انوینٹری درآمد کریں',
    hi: 'इन्वेंटरी आयात करें',
  );
  static const downloadFormat = TranslatableString(
    en: 'Download format',
    ar: 'تنزيل النموذج',
    ur: 'فارمیٹ ڈاؤن لوڈ کریں',
    hi: 'फ़ॉर्मेट डाउनलोड करें',
  );
  static const exportRegister = TranslatableString(
    en: 'Export register',
    ar: 'تصدير السجل',
    ur: 'رجسٹر ایکسپورٹ کریں',
    hi: 'रजिस्टर निर्यात करें',
  );
  static const manageCategories = TranslatableString(
    en: 'Manage categories',
    ar: 'إدارة الفئات',
    ur: 'کیٹیگریز منظم کریں',
    hi: 'श्रेणियां प्रबंधित करें',
  );
  static const categoryCoverage = TranslatableString(
    en: 'Category coverage',
    ar: 'تغطية الفئات',
    ur: 'کیٹیگری کوریج',
    hi: 'श्रेणी कवरेज',
  );
  static const recentActivity = TranslatableString(
    en: 'Recent stock activity',
    ar: 'نشاط المخزون الأخير',
    ur: 'حالیہ اسٹاک سرگرمی',
    hi: 'हाल की स्टॉक गतिविधि',
  );
  static const search = TranslatableString(
    en: 'Search code, item, category or location',
    ar: 'ابحث بالرمز أو الصنف أو الفئة أو الموقع',
    ur: 'کوڈ، آئٹم، کیٹیگری یا مقام تلاش کریں',
    hi: 'कोड, आइटम, श्रेणी या स्थान खोजें',
  );
  static const allStock = TranslatableString(
    en: 'All stock',
    ar: 'كل المخزون',
    ur: 'تمام اسٹاک',
    hi: 'सभी स्टॉक',
  );
  static const lowStock = TranslatableString(
    en: 'Low stock',
    ar: 'مخزون منخفض',
    ur: 'کم اسٹاک',
    hi: 'कम स्टॉक',
  );
  static const outOfStock = TranslatableString(
    en: 'Out of stock',
    ar: 'نفد المخزون',
    ur: 'اسٹاک ختم',
    hi: 'स्टॉक समाप्त',
  );
  static const healthy = TranslatableString(
    en: 'Healthy',
    ar: 'جيد',
    ur: 'صحت مند',
    hi: 'स्वस्थ',
  );
  static const uncategorized = TranslatableString(
    en: 'Uncategorized',
    ar: 'غير مصنف',
    ur: 'غیر درجہ بند',
    hi: 'अवर्गीकृत',
  );
  static const itemCode = TranslatableString(
    en: 'Item code',
    ar: 'رمز الصنف',
    ur: 'آئٹم کوڈ',
    hi: 'आइटम कोड',
  );
  static const category = TranslatableString(
    en: 'Category',
    ar: 'الفئة',
    ur: 'کیٹیگری',
    hi: 'श्रेणी',
  );
  static const location = TranslatableString(
    en: 'Location / Bin',
    ar: 'الموقع / الرف',
    ur: 'مقام / بن',
    hi: 'स्थान / बिन',
  );
  static const minimumStock = TranslatableString(
    en: 'Minimum stock',
    ar: 'الحد الأدنى للمخزون',
    ur: 'کم از کم اسٹاک',
    hi: 'न्यूनतम स्टॉक',
  );
  static const notes = TranslatableString(
    en: 'Notes',
    ar: 'ملاحظات',
    ur: 'نوٹس',
    hi: 'नोट्स',
  );
  static const stockQuantity = TranslatableString(
    en: 'Stock quantity',
    ar: 'كمية المخزون',
    ur: 'اسٹاک مقدار',
    hi: 'स्टॉक मात्रा',
  );
  static const newCategory = TranslatableString(
    en: 'Create as a new category',
    ar: 'إنشاء كفئة جديدة',
    ur: 'نئی کیٹیگری بنائیں',
    hi: 'नई श्रेणी बनाएं',
  );
  static const categoryName = TranslatableString(
    en: 'Category name',
    ar: 'اسم الفئة',
    ur: 'کیٹیگری نام',
    hi: 'श्रेणी नाम',
  );
  static const importTitle = TranslatableString(
    en: 'Import warehouse inventory',
    ar: 'استيراد مخزون المستودع',
    ur: 'گودام انوینٹری درآمد کریں',
    hi: 'वेयरहाउस इन्वेंटरी आयात करें',
  );
  static const importHelp = TranslatableString(
    en: 'Review every row before commit. Close matches are suggestions only; accepted wording is retained as an alias.',
    ar: 'راجع كل صف قبل الحفظ. المطابقات القريبة اقتراحات فقط، ويُحتفظ بالنص المقبول كاسم بديل.',
    ur: 'محفوظ کرنے سے پہلے ہر قطار دیکھیں۔ قریبی میچ صرف تجاویز ہیں؛ قبول شدہ عبارت بطور عرف محفوظ رہتی ہے۔',
    hi: 'कमिट से पहले हर पंक्ति देखें। निकट मिलान केवल सुझाव हैं; स्वीकृत शब्द उपनाम के रूप में सुरक्षित रहता है।',
  );
  static const selectFile = TranslatableString(
    en: 'Select Excel or CSV file',
    ar: 'اختر ملف Excel أو CSV',
    ur: 'Excel یا CSV فائل منتخب کریں',
    hi: 'Excel या CSV फ़ाइल चुनें',
  );
  static const reviewImport = TranslatableString(
    en: 'Review import',
    ar: 'مراجعة الاستيراد',
    ur: 'درآمد کا جائزہ',
    hi: 'आयात की समीक्षा',
  );
  static const commitImport = TranslatableString(
    en: 'Commit import',
    ar: 'حفظ الاستيراد',
    ur: 'درآمد محفوظ کریں',
    hi: 'आयात कमिट करें',
  );
  static const rows = TranslatableString(
    en: 'Rows',
    ar: 'الصفوف',
    ur: 'قطاریں',
    hi: 'पंक्तियां',
  );
  static const errors = TranslatableString(
    en: 'Errors',
    ar: 'الأخطاء',
    ur: 'غلطیاں',
    hi: 'त्रुटियां',
  );
  static const warnings = TranslatableString(
    en: 'Warnings',
    ar: 'التحذيرات',
    ur: 'تنبیہات',
    hi: 'चेतावनियां',
  );
  static const categoryDecision = TranslatableString(
    en: 'Choose an existing category or confirm a new one.',
    ar: 'اختر فئة موجودة أو أكد فئة جديدة.',
    ur: 'موجودہ کیٹیگری منتخب کریں یا نئی کی تصدیق کریں۔',
    hi: 'मौजूदा श्रेणी चुनें या नई की पुष्टि करें।',
  );
  static const reviewRow = TranslatableString(
    en: 'Review this row before import.',
    ar: 'راجع هذا الصف قبل الاستيراد.',
    ur: 'درآمد سے پہلے اس قطار کا جائزہ لیں۔',
    hi: 'आयात से पहले इस पंक्ति की समीक्षा करें।',
  );
  static const importSucceeded = TranslatableString(
    en: 'Inventory import committed',
    ar: 'تم حفظ استيراد المخزون',
    ur: 'انوینٹری درآمد محفوظ ہوگئی',
    hi: 'इन्वेंटरी आयात कमिट हुआ',
  );
  static const noMovements = TranslatableString(
    en: 'No stock movements yet.',
    ar: 'لا توجد حركات مخزون حتى الآن.',
    ur: 'ابھی کوئی اسٹاک موومنٹ نہیں۔',
    hi: 'अभी कोई स्टॉक मूवमेंट नहीं है।',
  );
  static const noReservations = TranslatableString(
    en: 'No active reservations.',
    ar: 'لا توجد حجوزات نشطة.',
    ur: 'کوئی فعال ریزرویشن نہیں۔',
    hi: 'कोई सक्रिय आरक्षण नहीं।',
  );
  static const request = TranslatableString(
    en: 'Request',
    ar: 'الطلب',
    ur: 'درخواست',
    hi: 'अनुरोध',
  );
  static const createdBy = TranslatableString(
    en: 'Created by',
    ar: 'أنشأها',
    ur: 'تخلیق کنندہ',
    hi: 'बनाने वाला',
  );
  static const active = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال',
    hi: 'सक्रिय',
  );
  static const noItems = TranslatableString(
    en: 'No warehouse items match these filters.',
    ar: 'لا توجد أصناف تطابق عوامل التصفية.',
    ur: 'کوئی گودام آئٹم ان فلٹرز سے مطابقت نہیں رکھتا۔',
    hi: 'कोई वेयरहाउस आइटम इन फ़िल्टर से मेल नहीं खाता।',
  );
  static const savingFailed = TranslatableString(
    en: 'The server did not confirm the change. Nothing was shown as saved.',
    ar: 'لم يؤكد الخادم التغيير. لم يتم إظهار أي حفظ.',
    ur: 'سرور نے تبدیلی کی تصدیق نہیں کی۔ کچھ محفوظ نہیں دکھایا گیا۔',
    hi: 'सर्वर ने परिवर्तन की पुष्टि नहीं की। कुछ भी सहेजा हुआ नहीं दिखाया गया।',
  );
}
