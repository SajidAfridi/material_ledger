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
  static const warehouseInventory = TranslatableString(
    en: 'Warehouse Inventory',
    ar: 'مخزون المستودع',
    ur: 'گودام انوینٹری',
    hi: 'वेयरहाउस इन्वेंटरी',
  );
  static const procurementWorkspace = TranslatableString(
    en: 'PROCUREMENT WORKSPACE',
    ar: 'مساحة عمل المشتريات',
    ur: 'خریداری ورک اسپیس',
    hi: 'खरीद कार्यक्षेत्र',
  );
  static const subtitle = TranslatableString(
    en: 'Control physical stock, active reservations and every quantity-changing movement from one dependable workspace.',
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
  static const activeStockItems = TranslatableString(
    en: 'Active stock items',
    ar: 'أصناف المخزون النشطة',
    ur: 'فعال اسٹاک آئٹمز',
    hi: 'सक्रिय स्टॉक आइटम',
  );
  static const itemsWithReservations = TranslatableString(
    en: 'Items with reservations',
    ar: 'أصناف عليها حجوزات',
    ur: 'ریزرویشن والے آئٹمز',
    hi: 'आरक्षण वाले आइटम',
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
    en: 'Stock quantity remains controlled',
    ar: 'المتاح = الموجود - المحجوز',
    ur: 'دستیاب = موجود - محفوظ',
    hi: 'उपलब्ध = ऑन हैंड - आरक्षित',
  );
  static const formulaHelp = TranslatableString(
    en: 'On Hand physical stock - Reserved active commitments = Available to arrange or dispatch. Reserved is read-only here and changes only through the Material Request lifecycle.',
    ar: 'تحمي الحجوزات الطلبات المعتمدة. تضيف عمليات الاستيراد والتعديل حركة مخزون دائماً.',
    ur: 'ریزرویشن منظور شدہ درخواستوں کو محفوظ رکھتے ہیں۔ درآمد اور ایڈجسٹمنٹ ہمیشہ اسٹاک موومنٹ شامل کرتے ہیں۔',
    hi: 'आरक्षण स्वीकृत अनुरोधों की रक्षा करते हैं। आयात और समायोजन हमेशा स्टॉक मूवमेंट जोड़ते हैं।',
  );
  static const onHand = TranslatableString(
    en: 'On Hand',
    ar: 'الموجود',
    ur: 'موجود',
    hi: 'ऑन हैंड',
  );
  static const reserved = TranslatableString(
    en: 'Reserved',
    ar: 'المحجوز',
    ur: 'محفوظ',
    hi: 'आरक्षित',
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
  static const downloadImportFormat = TranslatableString(
    en: 'Download import format',
    ar: 'تنزيل نموذج الاستيراد',
    ur: 'درآمدی فارمیٹ ڈاؤن لوڈ کریں',
    hi: 'आयात प्रारूप डाउनलोड करें',
  );
  static const chooseControlledAction = TranslatableString(
    en: 'Choose the controlled action you need. Stock quantities are changed only through movements.',
    ar: 'اختر الإجراء المنضبط المطلوب. تتغير الكميات فقط من خلال الحركات.',
    ur: 'مطلوبہ کنٹرول شدہ عمل منتخب کریں۔ مقدار صرف موومنٹس سے بدلتی ہے۔',
    hi: 'आवश्यक नियंत्रित कार्रवाई चुनें। मात्रा केवल मूवमेंट से बदलती है।',
  );
  static const createInventoryItem = TranslatableString(
    en: 'Create inventory item',
    ar: 'إنشاء صنف مخزون',
    ur: 'انوینٹری آئٹم بنائیں',
    hi: 'इन्वेंटरी आइटम बनाएं',
  );
  static const createInventoryItemHelp = TranslatableString(
    en: 'Add the item master and optionally record its opening balance.',
    ar: 'أضف سجل الصنف وسجّل الرصيد الافتتاحي اختيارياً.',
    ur: 'آئٹم ماسٹر شامل کریں اور اختیاری طور پر اوپننگ بیلنس درج کریں۔',
    hi: 'आइटम मास्टर जोड़ें और वैकल्पिक रूप से शुरुआती शेष दर्ज करें।',
  );
  static const adjustExistingStock = TranslatableString(
    en: 'Receive or adjust existing stock',
    ar: 'استلام أو تعديل مخزون موجود',
    ur: 'موجودہ اسٹاک وصول یا ایڈجسٹ کریں',
    hi: 'मौजूदा स्टॉक प्राप्त या समायोजित करें',
  );
  static const adjustExistingStockHelp = TranslatableString(
    en: 'Record stock in, stock out or a controlled correction.',
    ar: 'سجّل الإدخال أو الإخراج أو التصحيح المنضبط.',
    ur: 'اسٹاک اِن، آؤٹ یا کنٹرول شدہ تصحیح درج کریں۔',
    hi: 'स्टॉक इन, आउट या नियंत्रित सुधार दर्ज करें।',
  );
  static const movementTrust = TranslatableString(
    en: 'Current on hand is never edited directly. Every change records the actor, time, reason and resulting balance.',
    ar: 'لا يتم تعديل الموجود مباشرة. كل تغيير يسجل المنفذ والوقت والسبب والرصيد الناتج.',
    ur: 'موجودہ مقدار براہ راست تبدیل نہیں ہوتی۔ ہر تبدیلی عامل، وقت، وجہ اور نتیجہ درج کرتی ہے۔',
    hi: 'ऑन हैंड सीधे संपादित नहीं होता। हर बदलाव कर्ता, समय, कारण और परिणाम दर्ज करता है।',
  );
  static const itemIdentity = TranslatableString(
    en: 'Item identity',
    ar: 'هوية الصنف',
    ur: 'آئٹم شناخت',
    hi: 'आइटम पहचान',
  );
  static const itemCodeOptional = TranslatableString(
    en: 'Item code optional',
    ar: 'رمز الصنف اختياري',
    ur: 'آئٹم کوڈ اختیاری',
    hi: 'आइटम कोड वैकल्पिक',
  );
  static const autoGenerated = TranslatableString(
    en: 'Auto-generated when blank',
    ar: 'يتم إنشاؤه تلقائياً عند تركه فارغاً',
    ur: 'خالی ہونے پر خود بنے گا',
    hi: 'खाली होने पर स्वतः बनेगा',
  );
  static const materialEquipmentDescription = TranslatableString(
    en: 'Material or equipment description',
    ar: 'وصف المادة أو المعدة',
    ur: 'مواد یا سامان کی تفصیل',
    hi: 'सामग्री या उपकरण का विवरण',
  );
  static const size = TranslatableString(
    en: 'Size',
    ar: 'المقاس',
    ur: 'سائز',
    hi: 'आकार',
  );
  static const modelReference = TranslatableString(
    en: 'Model / equipment reference',
    ar: 'مرجع الطراز / المعدة',
    ur: 'ماڈل / سامان حوالہ',
    hi: 'मॉडल / उपकरण संदर्भ',
  );
  static const openingBalance = TranslatableString(
    en: 'Opening balance optional',
    ar: 'الرصيد الافتتاحي اختياري',
    ur: 'اوپننگ بیلنس اختیاری',
    hi: 'प्रारंभिक शेष वैकल्पिक',
  );
  static const openingQuantity = TranslatableString(
    en: 'Opening quantity',
    ar: 'الكمية الافتتاحية',
    ur: 'اوپننگ مقدار',
    hi: 'प्रारंभिक मात्रा',
  );
  static const openingReference = TranslatableString(
    en: 'Opening reference optional',
    ar: 'مرجع الافتتاح اختياري',
    ur: 'اوپننگ حوالہ اختیاری',
    hi: 'प्रारंभिक संदर्भ वैकल्पिक',
  );
  static const typeCategory = TranslatableString(
    en: 'Start typing a category',
    ar: 'ابدأ بكتابة الفئة',
    ur: 'کیٹیگری لکھنا شروع کریں',
    hi: 'श्रेणी लिखना शुरू करें',
  );
  static const createCategoryNamed = TranslatableString(
    en: 'Create',
    ar: 'إنشاء',
    ur: 'بنائیں',
    hi: 'बनाएं',
  );
  static const optionalParent = TranslatableString(
    en: 'Parent family optional',
    ar: 'الفئة الرئيسية اختيارية',
    ur: 'پیرنٹ فیملی اختیاری',
    hi: 'मूल परिवार वैकल्पिक',
  );
  static const selectExistingItem = TranslatableString(
    en: 'Select an inventory item',
    ar: 'اختر صنف مخزون',
    ur: 'انوینٹری آئٹم منتخب کریں',
    hi: 'इन्वेंटरी आइटम चुनें',
  );
  static const correction = TranslatableString(
    en: 'Correction',
    ar: 'تصحيح',
    ur: 'تصحیح',
    hi: 'सुधार',
  );
  static const referenceOptional = TranslatableString(
    en: 'Reference optional',
    ar: 'المرجع اختياري',
    ur: 'حوالہ اختیاری',
    hi: 'संदर्भ वैकल्पिक',
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
  static const searchInventoryItem = TranslatableString(
    en: 'Search item code or description',
    ar: 'ابحث برمز الصنف أو الوصف',
    ur: 'آئٹم کوڈ یا تفصیل تلاش کریں',
    hi: 'आइटम कोड या विवरण खोजें',
  );
  static const available = TranslatableString(
    en: 'available',
    ar: 'متاح',
    ur: 'دستیاب',
    hi: 'उपलब्ध',
  );
  static const warehouseItems = TranslatableString(
    en: 'warehouse items',
    ar: 'أصناف المستودع',
    ur: 'گودام آئٹمز',
    hi: 'वेयरहाउस आइटम',
  );
  static const alias = TranslatableString(
    en: 'alias',
    ar: 'اسم بديل',
    ur: 'عرف',
    hi: 'उपनाम',
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
