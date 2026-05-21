import 'app_language.dart';

/// All UI string translations keyed by label ID.
///
/// English is always the primary language shown.
/// Secondary text is selected by [AppLanguage].
abstract final class AppStrings {
  // ─── Navigation ───────────────────────────────────────────
  static const dashboard = TranslatableString(
    en: 'Dashboard',
    ar: 'لوحة القيادة',
    ur: 'ڈیش بورڈ',
    hi: 'डैशबोर्ड',
  );
  static const inventory = TranslatableString(
    en: 'Inventory',
    ar: 'المخزون',
    ur: 'انوینٹری',
    hi: 'इन्वेंटरी',
  );
  static const transactions = TranslatableString(
    en: 'Transactions',
    ar: 'المعاملات',
    ur: 'لین دین',
    hi: 'लेन-देन',
  );
  static const settings = TranslatableString(
    en: 'Settings',
    ar: 'الإعدادات',
    ur: 'ترتیبات',
    hi: 'सेटिंग्स',
  );
  static const alertCenter = TranslatableString(
    en: 'Alert Center',
    ar: 'مركز التنبيهات',
    ur: 'الرٹ سینٹر',
    hi: 'अलर्ट सेंटर',
  );
  static const recentUpdates = TranslatableString(
    en: 'Recent Updates',
    ar: 'التحديثات الأخيرة',
    ur: 'حالیہ اپڈیٹس',
    hi: 'हालिया अपडेट',
  );

  // ─── Dashboard ────────────────────────────────────────────
  static const totalStockValue = TranslatableString(
    en: 'Total Stock Value',
    ar: 'إجمالي قيمة المخزون',
    ur: 'کل اسٹاک کی قیمت',
    hi: 'कुल स्टॉक मूल्य',
  );
  static const materials = TranslatableString(
    en: 'Materials',
    ar: 'المواد',
    ur: 'مواد',
    hi: 'सामग्री',
  );
  static const recentActivity = TranslatableString(
    en: 'Recent Activity',
    ar: 'النشاط الأخير',
    ur: 'حالیہ سرگرمی',
    hi: 'हालिया गतिविधि',
  );
  static const noRecentActivity = TranslatableString(
    en: 'No recent activity',
    ar: 'لا يوجد نشاط حديث',
    ur: 'کوئی حالیہ سرگرمی نہیں',
    hi: 'कोई हालिया गतिविधि नहीं',
  );
  static const noDataYet = TranslatableString(
    en: 'No data yet',
    ar: 'لا توجد بيانات بعد',
    ur: 'ابھی تک کوئی ڈیٹا نہیں',
    hi: 'अभी तक कोई डेटा नहीं',
  );

  // ─── Inventory ────────────────────────────────────────────
  static const noMaterialsAdded = TranslatableString(
    en: 'No materials added yet',
    ar: 'لم تتم إضافة مواد بعد',
    ur: 'ابھی تک کوئی مواد شامل نہیں کیا گیا',
    hi: 'अभी तक कोई सामग्री नहीं जोड़ी गई',
  );
  static const addMaterial = TranslatableString(
    en: 'Add Material',
    ar: 'إضافة مادة',
    ur: 'مواد شامل کریں',
    hi: 'सामग्री जोड़ें',
  );
  static const tapToAddFirst = TranslatableString(
    en: 'Tap + to add your first material',
    ar: 'اضغط + لإضافة أول مادة',
    ur: 'پہلا مواد شامل کرنے کے لیے + دبائیں',
    hi: 'पहली सामग्री जोड़ने के लिए + दबाएं',
  );

  // ─── Transactions ─────────────────────────────────────────
  static const noTransactions = TranslatableString(
    en: 'No transactions recorded',
    ar: 'لم يتم تسجيل معاملات',
    ur: 'کوئی لین دین ریکارڈ نہیں ہوا',
    hi: 'कोई लेन-देन दर्ज नहीं',
  );
  static const transactionsWillAppear = TranslatableString(
    en: 'Transactions will appear here once you start recording',
    ar: 'ستظهر المعاملات هنا بمجرد بدء التسجيل',
    ur: 'ریکارڈنگ شروع کرنے پر لین دین یہاں ظاہر ہوں گے',
    hi: 'रिकॉर्डिंग शुरू करने पर लेन-देन यहां दिखाई देंगे',
  );

  // ─── Settings ─────────────────────────────────────────────
  static const secondaryLanguage = TranslatableString(
    en: 'Secondary Language',
    ar: 'اللغة الثانوية',
    ur: 'ثانوی زبان',
    hi: 'द्वितीयक भाषा',
  );
  static const currency = TranslatableString(
    en: 'Currency',
    ar: 'العملة',
    ur: 'کرنسی',
    hi: 'मुद्रा',
  );
  static const appearance = TranslatableString(
    en: 'Appearance',
    ar: 'المظهر',
    ur: 'ظاہری شکل',
    hi: 'दिखावट',
  );
  static const backupSync = TranslatableString(
    en: 'Backup & Sync',
    ar: 'النسخ الاحتياطي والمزامنة',
    ur: 'بیک اپ اور سنک',
    hi: 'बैकअप और सिंक',
  );
  static const about = TranslatableString(
    en: 'About',
    ar: 'حول',
    ur: 'ایپ کے بارے میں',
    hi: 'के बारे में',
  );
  static const logout = TranslatableString(
    en: 'Logout',
    ar: 'تسجيل الخروج',
    ur: 'لاگ آؤٹ',
    hi: 'लॉगआउट',
  );
  static const light = TranslatableString(
    en: 'Light',
    ar: 'فاتح',
    ur: 'ہلکا',
    hi: 'हल्का',
  );

  // ─── Onboarding ───────────────────────────────────────────
  static const welcomeTo = TranslatableString(
    en: 'Welcome to GodownPro',
    ar: 'مرحباً بك في GodownPro',
    ur: 'گودام پرو میں خوش آمدید',
    hi: 'GodownPro में आपका स्वागत है',
  );
  static const selectLanguage = TranslatableString(
    en: 'SELECT LANGUAGE',
    ar: 'اختر اللغة',
    ur: 'زبان منتخب کریں',
    hi: 'भाषा चुनें',
  );
  static const getStarted = TranslatableString(
    en: 'Get Started',
    ar: 'ابدأ الآن',
    ur: 'شروع کریں',
    hi: 'शुरू करें',
  );
  static const dataSyncReady = TranslatableString(
    en: 'Data Sync Ready',
    ar: 'مزامنة البيانات جاهزة',
    ur: 'ڈیٹا کی ہم آہنگی تیار ہے',
    hi: 'डेटा सिंक तैयार',
  );
  static const dataSyncDesc = TranslatableString(
    en: 'Your inventory preferences will be synced across all architectural ledgers in your warehouse cluster.',
    ar: 'ستتم مزامنة تفضيلات المخزون عبر جميع دفاتر المعمار في مجموعة المستودعات الخاصة بك.',
    ur: 'آپ کی انوینٹری ترجیحات آپ کے گودام کلسٹر میں تمام معماری لیجرز میں ہم آہنگ ہوں گی۔',
    hi: 'आपकी इन्वेंटरी प्राथमिकताएं आपके वेयरहाउस क्लस्टर के सभी आर्किटेक्चरल लेजर में सिंक की जाएंगी।',
  );

  // ─── Login ───────────────────────────────────────────────
  static const login = TranslatableString(
    en: 'Login',
    ar: 'سجل الدخول',
    ur: 'لاگ ان کریں',
    hi: 'लॉगिन करें',
  );
  static const emailAddress = TranslatableString(
    en: 'Email Address',
    ar: 'البريد الإلكتروني',
    ur: 'ای میل ایڈریس',
    hi: 'ईमेल पता',
  );
  static const password = TranslatableString(
    en: 'Password',
    ar: 'كلمة المرور',
    ur: 'پاس ورڈ',
    hi: 'पासवर्ड',
  );
  static const forgotPassword = TranslatableString(
    en: 'Forgot Password?',
    ar: 'هل نسيت كلمة المرور؟',
    ur: 'پاس ورڈ بھول گئے؟',
    hi: 'पासवर्ड भूल गए?',
  );
  static const accessSystem = TranslatableString(
    en: 'Access System',
    ar: 'دخول النظام',
    ur: 'سسٹم تک رسائی',
    hi: 'सिस्टम एक्सेस',
  );
  static const secureIndustrialEnvironment = TranslatableString(
    en: 'SECURE INDUSTRIAL ENVIRONMENT',
    ar: 'بيئة صناعية آمنة',
    ur: 'محفوظ صنعتی ماحول',
    hi: 'सुरक्षित औद्योगिक वातावरण',
  );
  static const signIn = TranslatableString(
    en: 'Sign In',
    ar: 'سائن ان کریں',
    ur: 'سائن ان کریں',
    hi: 'साइन इन करें',
  );
  static const rememberMe = TranslatableString(
    en: 'Remember Me',
    ar: 'تذكرني',
    ur: 'مجھے یاد رکھیں',
    hi: 'मुझे याद रखें',
  );
  static const contactSupport = TranslatableString(
    en: 'Contact Support',
    ar: 'اتصل بالدعم',
    ur: 'سپورٹ سے رابطہ کریں',
    hi: 'सहायता से संपर्क करें',
  );

  // ─── Splash ───────────────────────────────────────────────
  static const architecturalLedger = TranslatableString(
    en: 'THE ARCHITECTURAL LEDGER',
    ar: 'السجل المعماري',
    ur: 'معماری لیجر',
    hi: 'वास्तुशिल्प खाता',
  );

  // ─── Add Material ───────────────────────────────────────────
  static const addNewMaterial = TranslatableString(
    en: 'Add New Material',
    ar: 'إضافة مادة جديدة',
    ur: 'نیا مواد شامل کریں',
    hi: 'नई सामग्री जोड़ें',
  );
  static const materialName = TranslatableString(
    en: 'Material Name',
    ar: 'اسم المادة',
    ur: 'مواد کا نام',
    hi: 'सामग्री का नाम',
  );
  static const materialNameUrdu = TranslatableString(
    en: 'Name in Secondary Language',
    ar: 'الاسم باللغة الثانوية',
    ur: 'ثانوی زبان میں نام',
    hi: 'द्वितीयक भाषा में नाम',
  );
  static const category = TranslatableString(
    en: 'Category',
    ar: 'الفئة',
    ur: 'زمرہ',
    hi: 'श्रेणी',
  );
  static const unit = TranslatableString(
    en: 'Unit',
    ar: 'الوحدة',
    ur: 'اکائی',
    hi: 'इकाई',
  );
  static const quantity = TranslatableString(
    en: 'Quantity',
    ar: 'الكمية',
    ur: 'مقدار',
    hi: 'मात्रा',
  );
  static const unitPrice = TranslatableString(
    en: 'Unit Price',
    ar: 'سعر الوحدة',
    ur: 'فی اکائی قیمت',
    hi: 'इकाई मूल्य',
  );
  static const minStockLevel = TranslatableString(
    en: 'Min. Stock Level',
    ar: 'الحد الأدنى للمخزون',
    ur: 'کم از کم اسٹاک',
    hi: 'न्यूनतम स्टॉक स्तर',
  );
  static const saveMaterial = TranslatableString(
    en: 'Save Material',
    ar: 'حفظ المادة',
    ur: 'مواد محفوظ کریں',
    hi: 'सामग्री सहेजें',
  );
  static const editMaterial = TranslatableString(
    en: 'Edit Material',
    ar: 'تعديل المادة',
    ur: 'مواد ترمیم کریں',
    hi: 'सामग्री संपादित करें',
  );
  static const saveChanges = TranslatableString(
    en: 'Save Changes',
    ar: 'حفظ التغييرات',
    ur: 'تبدیلیاں محفوظ کریں',
    hi: 'परिवर्तन सहेजें',
  );
  static const filterAll = TranslatableString(
    en: 'All',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const filterIncoming = TranslatableString(
    en: 'Incoming',
    ar: 'الوارد',
    ur: 'آنے والا',
    hi: 'आने वाला',
  );
  static const filterOutgoing = TranslatableString(
    en: 'Outgoing',
    ar: 'الصادر',
    ur: 'جانے والا',
    hi: 'जाने वाला',
  );
  static const filterByType = TranslatableString(
    en: 'Filter by type',
    ar: 'تصفية حسب النوع',
    ur: 'قسم کے مطابق فلٹر',
    hi: 'प्रकार से फ़िल्टर',
  );
  static const searchMaterialsHint = TranslatableString(
    en: 'Search materials...',
    ar: 'البحث في المواد...',
    ur: 'مواد تلاش کریں...',
    hi: 'सामग्री खोजें...',
  );
  static const fieldRequired = TranslatableString(
    en: 'This field is required',
    ar: 'هذا الحقل مطلوب',
    ur: 'یہ فیلڈ ضروری ہے',
    hi: 'यह फ़ील्ड आवश्यक है',
  );
  static const enterValidNumber = TranslatableString(
    en: 'Enter a valid number',
    ar: 'أدخل رقمًا صالحًا',
    ur: 'ایک درست نمبر درج کریں',
    hi: 'एक मान्य संख्या दर्ज करें',
  );
  static const optional = TranslatableString(
    en: 'Optional',
    ar: 'اختياري',
    ur: 'اختیاری',
    hi: 'वैकल्पिक',
  );
  static const materialAdded = TranslatableString(
    en: 'Material added successfully',
    ar: 'تمت إضافة المادة بنجاح',
    ur: 'مواد کامیابی سے شامل کیا گیا',
    hi: 'सामग्री सफलतापूर्वक जोड़ी गई',
  );

  // ─── Record Transaction ─────────────────────────────────────
  static const recordTransaction = TranslatableString(
    en: 'Record Transaction',
    ar: 'تسجيل معاملة',
    ur: 'لین دین ریکارڈ کریں',
    hi: 'लेन-देन दर्ज करें',
  );
  static const incoming = TranslatableString(
    en: 'Incoming',
    ar: 'وارد',
    ur: 'آمد',
    hi: 'आवक',
  );
  static const outgoing = TranslatableString(
    en: 'Outgoing',
    ar: 'صادر',
    ur: 'روانگی',
    hi: 'जावक',
  );
  static const notes = TranslatableString(
    en: 'Notes',
    ar: 'ملاحظات',
    ur: 'نوٹس',
    hi: 'टिप्पणियाँ',
  );
  static const record = TranslatableString(
    en: 'Record',
    ar: 'تسجيل',
    ur: 'ریکارڈ',
    hi: 'दर्ज करें',
  );
  static const transactionRecorded = TranslatableString(
    en: 'Transaction recorded',
    ar: 'تم تسجيل المعاملة',
    ur: 'لین دین ریکارڈ ہوا',
    hi: 'लेन-देन दर्ज किया गया',
  );
  static const insufficientStock = TranslatableString(
    en: 'Insufficient stock',
    ar: 'المخزون غير كافٍ',
    ur: 'اسٹاک ناکافی ہے',
    hi: 'अपर्याप्त स्टॉक',
  );
  static const selectMaterial = TranslatableString(
    en: 'Select Material',
    ar: 'اختر المادة',
    ur: 'مواد منتخب کریں',
    hi: 'सामग्री चुनें',
  );

  // ─── Inventory Detail ───────────────────────────────────────
  static const inStock = TranslatableString(
    en: 'In Stock',
    ar: 'متوفر',
    ur: 'اسٹاک میں',
    hi: 'स्टॉक में',
  );
  static const lowStock = TranslatableString(
    en: 'Low Stock',
    ar: 'مخزون منخفض',
    ur: 'کم اسٹاک',
    hi: 'कम स्टॉक',
  );
  static const outOfStock = TranslatableString(
    en: 'Out of Stock',
    ar: 'نفذ المخزون',
    ur: 'اسٹاک ختم',
    hi: 'स्टॉक समाप्त',
  );
  static const totalValue = TranslatableString(
    en: 'Total Value',
    ar: 'القيمة الإجمالية',
    ur: 'کل قیمت',
    hi: 'कुल मूल्य',
  );
  static const delete = TranslatableString(
    en: 'Delete',
    ar: 'حذف',
    ur: 'حذف کریں',
    hi: 'हटाएं',
  );
  static const confirmDelete = TranslatableString(
    en: 'Are you sure you want to delete this material?',
    ar: 'هل أنت متأكد من حذف هذه المادة؟',
    ur: 'کیا آپ واقعی اس مواد کو حذف کرنا چاہتے ہیں؟',
    hi: 'क्या आप वाकई इस सामग्री को हटाना चाहते हैं?',
  );
  static const cancel = TranslatableString(
    en: 'Cancel',
    ar: 'إلغاء',
    ur: 'منسوخ',
    hi: 'रद्द करें',
  );
  static const today = TranslatableString(
    en: 'Today',
    ar: 'اليوم',
    ur: 'آج',
    hi: 'आज',
  );
  static const yesterday = TranslatableString(
    en: 'Yesterday',
    ar: 'أمس',
    ur: 'کل',
    hi: 'कल',
  );

  // ─── Engineer — Material Requests ────────────────────────────
  static const materialRequests = TranslatableString(
    en: 'Material Requests',
    ar: 'طلبات المواد',
    ur: 'مواد کی درخواستیں',
    hi: 'सामग्री अनुरोध',
  );
  static const allRequests = TranslatableString(
    en: 'All Requests',
    ar: 'جميع الطلبات',
    ur: 'تمام',
    hi: 'सभी अनुरोध',
  );
  static const recentRequests = TranslatableString(
    en: 'Recent',
    ar: 'الأخيرة',
    ur: 'حالیہ',
    hi: 'हालिया',
  );
  static const viewDetails = TranslatableString(
    en: 'VIEW DETAILS',
    ar: 'عرض التفاصيل',
    ur: 'تفصیلات دیکھیں',
    hi: 'विवरण देखें',
  );
  static const pickUp = TranslatableString(
    en: 'PICK UP',
    ar: 'استلام',
    ur: 'وصول کریں',
    hi: 'उठाएं',
  );
  static const historyLabel = TranslatableString(
    en: 'HISTORY',
    ar: 'السجل',
    ur: 'تاریخ',
    hi: 'इतिहास',
  );
  static const dateLabel = TranslatableString(
    en: 'Date',
    ar: 'التاريخ',
    ur: 'تاریخ',
    hi: 'तारीख',
  );
  static const itemCount = TranslatableString(
    en: 'Item Count',
    ar: 'عدد العناصر',
    ur: 'اشیاء کی تعداد',
    hi: 'वस्तु गणना',
  );
  static const items = TranslatableString(
    en: 'Items',
    ar: 'عناصر',
    ur: 'اشیاء',
    hi: 'वस्तुएं',
  );

  // ─── Engineer — Navigation ───────────────────────────────────
  static const requests = TranslatableString(
    en: 'Requests',
    ar: 'الطلبات',
    ur: 'درخواستیں',
    hi: 'अनुरोध',
  );
  static const browse = TranslatableString(
    en: 'Browse',
    ar: 'تصفح',
    ur: 'تلاش',
    hi: 'ब्राउज़',
  );
  static const profile = TranslatableString(
    en: 'Profile',
    ar: 'الملف الشخصي',
    ur: 'پروفائل',
    hi: 'प्रोफ़ाइल',
  );

  // ─── Engineer — Status Labels ────────────────────────────────
  static const statusPending = TranslatableString(
    en: 'PENDING',
    ar: 'معلق',
    ur: 'زیر التواء',
    hi: 'लंबित',
  );
  static const statusAvailable = TranslatableString(
    en: 'AVAILABLE',
    ar: 'متاح',
    ur: 'دستیاب',
    hi: 'उपलब्ध',
  );
  static const statusDeployed = TranslatableString(
    en: 'DEPLOYED',
    ar: 'تم النشر',
    ur: 'تعینات',
    hi: 'तैनात',
  );
  static const statusRejected = TranslatableString(
    en: 'REJECTED',
    ar: 'مرفوض',
    ur: 'مسترد',
    hi: 'अस्वीकृत',
  );

  // ─── Engineer — Empty / Misc ─────────────────────────────────
  static const noRequestsYet = TranslatableString(
    en: 'No material requests yet',
    ar: 'لا توجد طلبات مواد بعد',
    ur: 'ابھی تک کوئی مواد کی درخواست نہیں',
    hi: 'अभी तक कोई सामग्री अनुरोध नहीं',
  );
  static const tapToCreateRequest = TranslatableString(
    en: 'Tap + to create your first request',
    ar: 'اضغط + لإنشاء أول طلب',
    ur: 'پہلی درخواست بنانے کے لیے + دبائیں',
    hi: 'पहला अनुरोध बनाने के लिए + दबाएं',
  );
  static const browseWarehouse = TranslatableString(
    en: 'Browse Warehouse',
    ar: 'تصفح المستودع',
    ur: 'گودام تلاش کریں',
    hi: 'गोदाम ब्राउज़ करें',
  );
  static const browseDescription = TranslatableString(
    en: 'Explore available materials in the warehouse inventory',
    ar: 'استكشف المواد المتاحة في مخزون المستودع',
    ur: 'گودام کی انوینٹری میں دستیاب مواد دیکھیں',
    hi: 'गोदाम इन्वेंटरी में उपलब्ध सामग्री देखें',
  );
  static const notifications = TranslatableString(
    en: 'Notifications',
    ar: 'الإشعارات',
    ur: 'اطلاعات',
    hi: 'सूचनाएं',
  );
  static const totalPending = TranslatableString(
    en: 'Total Pending',
    ar: 'إجمالي المعلق',
    ur: 'کل زیر التواء',
    hi: 'कुल लंबित',
  );
  static const urgentAlerts = TranslatableString(
    en: 'Urgent Alerts',
    ar: 'تنبيهات عاجلة',
    ur: 'فوری الرٹس',
    hi: 'अत्यावश्यक अलर्ट',
  );
  static const notificationHealth = TranslatableString(
    en: 'Notification Health',
    ar: 'صحة الإشعارات',
    ur: 'اطلاعات کی کارکردگی',
    hi: 'अधिसूचना स्वास्थ्य',
  );
  static const latestActivity = TranslatableString(
    en: 'Latest Activity',
    ar: 'أحدث النشاطات',
    ur: 'تازہ ترین سرگرمی',
    hi: 'नवीनतम गतिविधि',
  );
  static const markAllRead = TranslatableString(
    en: 'Mark all read',
    ar: 'تحديد الكل كمقروء',
    ur: 'سب پڑھے ہوئے نشان کریں',
    hi: 'सभी पढ़े हुए चिह्नित करें',
  );
  static const searchAlerts = TranslatableString(
    en: 'Search system alerts...',
    ar: 'البحث في التنبيهات...',
    ur: 'الرٹس تلاش کریں...',
    hi: 'सिस्टम अलर्ट खोजें...',
  );
  static const filterAllUpper = TranslatableString(
    en: 'ALL',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const filterUnread = TranslatableString(
    en: 'UNREAD',
    ar: 'غير مقروء',
    ur: 'نہ پڑھے',
    hi: 'अपठित',
  );
  static const filterUrgent = TranslatableString(
    en: 'URGENT',
    ar: 'عاجل',
    ur: 'فوری',
    hi: 'अत्यावश्यक',
  );
  static const filterLast24h = TranslatableString(
    en: 'LAST 24 HOURS',
    ar: 'آخر 24 ساعة',
    ur: 'آخری 24 گھنٹے',
    hi: 'पिछले 24 घंटे',
  );
  static const responseRateUp = TranslatableString(
    en: 'Response rate is up by 12% today',
    ar: 'ارتفعت نسبة الاستجابة بنسبة 12٪ اليوم',
    ur: 'رسپانس کی شرح میں آج 12 فیصد اضافہ ہوا ہے',
    hi: 'आज प्रतिक्रिया दर 12% बढ़ी है',
  );
  static const noNotificationsForFilter = TranslatableString(
    en: 'No notifications match this filter',
    ar: 'لا توجد إشعارات تتطابق مع هذا الفلتر',
    ur: 'اس فلٹر سے کوئی اطلاع مطابقت نہیں رکھتی',
    hi: 'इस फ़िल्टर से कोई सूचना मेल नहीं खाती',
  );

  // ─── Engineer — New Request Form ────────────────────────────────
  static const newRequest = TranslatableString(
    en: 'New Request',
    ar: 'طلب جديد',
    ur: 'نئی درخواست',
    hi: 'नया अनुरोध',
  );
  static const projectName = TranslatableString(
    en: 'Project Name',
    ar: 'اسم المشروع',
    ur: 'پروجیکٹ کا نام',
    hi: 'परियोजना का नाम',
  );
  static const projectNameSecondary = TranslatableString(
    en: 'Name in Secondary Language',
    ar: 'الاسم باللغة الثانوية',
    ur: 'ثانوی زبان میں نام',
    hi: 'द्वितीयक भाषा में नाम',
  );
  static const siteLocation = TranslatableString(
    en: 'Site Location',
    ar: 'موقع الموقع',
    ur: 'سائٹ کا مقام',
    hi: 'साइट स्थान',
  );
  static const numberOfItems = TranslatableString(
    en: 'Number of Items',
    ar: 'عدد العناصر',
    ur: 'اشیاء کی تعداد',
    hi: 'वस्तुओं की संख्या',
  );
  static const priority = TranslatableString(
    en: 'Priority',
    ar: 'الأولوية',
    ur: 'ترجیح',
    hi: 'प्राथमिकता',
  );
  static const priorityNormal = TranslatableString(
    en: 'Normal',
    ar: 'عادي',
    ur: 'عام',
    hi: 'सामान्य',
  );
  static const priorityUrgent = TranslatableString(
    en: 'Urgent',
    ar: 'عاجل',
    ur: 'فوری',
    hi: 'अत्यावश्यक',
  );
  static const priorityCritical = TranslatableString(
    en: 'Critical',
    ar: 'حرج',
    ur: 'انتہائی ضروری',
    hi: 'गंभीर',
  );
  static const submitRequest = TranslatableString(
    en: 'Submit Request',
    ar: 'إرسال الطلب',
    ur: 'درخواست جمع کرائیں',
    hi: 'अनुरोध जमा करें',
  );
  static const requestSubmitted = TranslatableString(
    en: 'Request submitted successfully',
    ar: 'تم إرسال الطلب بنجاح',
    ur: 'درخواست کامیابی سے جمع ہو گئی',
    hi: 'अनुरोध सफलतापूर्वक जमा किया गया',
  );
  static const enterValidItemCount = TranslatableString(
    en: 'Enter a valid item count',
    ar: 'أدخل عدد عناصر صالح',
    ur: 'ایک درست تعداد درج کریں',
    hi: 'एक मान्य वस्तु संख्या दर्ज करें',
  );

  // ─── Engineer — My Requests (nav label) ─────────────────────────
  static const myRequests = TranslatableString(
    en: 'My Requests',
    ar: 'طلباتي',
    ur: 'میری درخواستیں',
    hi: 'मेरे अनुरोध',
  );

  // ─── Engineer — Request Detail Screen ───────────────────────────
  static const backToRequests = TranslatableString(
    en: 'Back to Requests',
    ar: 'العودة للطلبات',
    ur: 'واپس',
    hi: 'अनुरोधों पर वापस',
  );
  static const requestTimeline = TranslatableString(
    en: 'Request Timeline',
    ar: 'الجدول الزمني للطلب',
    ur: 'درخواست کی ٹائم لائن',
    hi: 'अनुरोध समयरेखा',
  );
  static const materialBreakdown = TranslatableString(
    en: 'Material Breakdown',
    ar: 'تفصيل المواد',
    ur: 'مواد کی تفصیل',
    hi: 'सामग्री विवरण',
  );
  static const verification = TranslatableString(
    en: 'Verification',
    ar: 'التحقق',
    ur: 'تصدیق',
    hi: 'सत्यापन',
  );
  static const totalValueLabel = TranslatableString(
    en: 'TOTAL VALUE',
    ar: 'القيمة الإجمالية',
    ur: 'کل مالیت',
    hi: 'कुल मूल्य',
  );
  static const issueDateLabel = TranslatableString(
    en: 'ISSUE DATE',
    ar: 'تاريخ الإصدار',
    ur: 'تاریخ اجراء',
    hi: 'जारी तिथि',
  );
  static const downloadReceipt = TranslatableString(
    en: 'Download Receipt',
    ar: 'تحميل الإيصال',
    ur: 'رسید ڈاؤن لوڈ کریں',
    hi: 'रसीद डाउनलोड करें',
  );
  static const printOrder = TranslatableString(
    en: 'Print Order',
    ar: 'طباعة الطلب',
    ur: 'پرنٹ کریں',
    hi: 'ऑर्डर प्रिंट करें',
  );
  static const requestCreated = TranslatableString(
    en: 'Request Created',
    ar: 'تم إنشاء الطلب',
    ur: 'درخواست بنائی گئی',
    hi: 'अनुरोध बनाया गया',
  );
  static const stockValidated = TranslatableString(
    en: 'Stock Validated',
    ar: 'تم التحقق من المخزون',
    ur: 'اسٹاک کی تصدیق ہو گئی',
    hi: 'स्टॉक सत्यापित',
  );
  static const requestDeployed = TranslatableString(
    en: 'Request Deployed',
    ar: 'تم نشر الطلب',
    ur: 'درخواست مکمل کر دی گئی ہے',
    hi: 'अनुरोध तैनात',
  );
  static const issuedBy = TranslatableString(
    en: 'ISSUED BY',
    ar: 'صدر بواسطة',
    ur: 'جاری کنندہ',
    hi: 'जारीकर्ता',
  );
  static const requestedBy = TranslatableString(
    en: 'REQUESTED BY',
    ar: 'مطلوب بواسطة',
    ur: 'درخواست کنندہ',
    hi: 'अनुरोधकर्ता',
  );
  static const reqQty = TranslatableString(
    en: 'REQ QTY',
    ar: 'الكمية المطلوبة',
    ur: 'درخواست',
    hi: 'अनुरोधित मात्रा',
  );
  static const issuedQty = TranslatableString(
    en: 'ISSUED QTY',
    ar: 'الكمية الصادرة',
    ur: 'جاری کردہ',
    hi: 'जारी मात्रा',
  );
  static const unitPriceLabel = TranslatableString(
    en: 'UNIT PRICE',
    ar: 'سعر الوحدة',
    ur: 'فی اکائی قیمت',
    hi: 'इकाई मूल्य',
  );
  static const itemLabel = TranslatableString(
    en: 'ITEM',
    ar: 'العنصر',
    ur: 'آئٹم',
    hi: 'वस्तु',
  );
  static const budgetCode = TranslatableString(
    en: 'Budget Code',
    ar: 'رمز الميزانية',
    ur: 'بجٹ کوڈ',
    hi: 'बजट कोड',
  );
  static const categories = TranslatableString(
    en: 'Categories',
    ar: 'الفئات',
    ur: 'زمرے',
    hi: 'श्रेणियाँ',
  );
  static const updated = TranslatableString(
    en: 'Updated',
    ar: 'محدث',
    ur: 'اپ ڈیٹ',
    hi: 'अपडेट',
  );

  // ─── Browse Materials Screen ───────────────────────────────────
  static const totalItemsInStock = TranslatableString(
    en: 'Total Items in Stock',
    ar: 'إجمالي العناصر في المخزون',
    ur: 'اسٹاک میں کل اشیاء',
    hi: 'स्टॉक में कुल आइटम',
  );
  static const activeCategories = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال زمرے',
    hi: 'सक्रिय',
  );
  static const allMaterials = TranslatableString(
    en: 'All Materials',
    ar: 'جميع المواد',
    ur: 'تمام مواد',
    hi: 'सभी सामग्री',
  );
  static const concrete = TranslatableString(
    en: 'Concrete',
    ar: 'الخرسانة',
    ur: 'کنکریٹ',
    hi: 'कंक्रीट',
  );
  static const steel = TranslatableString(
    en: 'Steel',
    ar: 'الفولاذ',
    ur: 'سٹیل',
    hi: 'स्टील',
  );
  static const finishing = TranslatableString(
    en: 'Finishing',
    ar: 'التشطيب',
    ur: 'فنشنگ',
    hi: 'फिनिशिंग',
  );

  // ─── HVAC Browse Filters ───────────────────────────────────────
  static const valvesFittings = TranslatableString(
    en: 'Valves & Fittings',
    ar: 'الصمامات والتوصيلات',
    ur: 'والوز اور فٹنگز',
    hi: 'वाल्व और फिटिंग्स',
  );
  static const pipesDucts = TranslatableString(
    en: 'Pipes & Ducts',
    ar: 'الأنابيب والقنوات',
    ur: 'پائپ اور ڈکٹس',
    hi: 'पाइप और डक्ट',
  );
  static const fastenersTools = TranslatableString(
    en: 'Fasteners & Tools',
    ar: 'المثبتات والأدوات',
    ur: 'نٹ بولٹ اور اوزار',
    hi: 'फास्टनर और उपकरण',
  );
  static const stockLevel = TranslatableString(
    en: 'STOCK LEVEL',
    ar: 'مستوى المخزون',
    ur: 'اسٹاک کی سطح',
    hi: 'स्टॉक स्तर',
  );
  static const actions = TranslatableString(
    en: 'ACTIONS',
    ar: 'الإجراءات',
    ur: 'اعمال',
    hi: 'कार्रवाई',
  );
  static const addToRequest = TranslatableString(
    en: 'Add to\nRequest',
    ar: 'أضف إلى\nالطلب',
    ur: 'شامل\nکریں',
    hi: 'अनुरोध में\nजोड़ें',
  );
  static const healthy = TranslatableString(
    en: 'HEALTHY',
    ar: 'سليم',
    ur: 'صحت مند',
    hi: 'स्वस्थ',
  );
  static const moderate = TranslatableString(
    en: 'MODERATE',
    ar: 'متوسط',
    ur: 'معتدل',
    hi: 'मध्यम',
  );
  static const remaining = TranslatableString(
    en: 'remaining',
    ar: 'متبقي',
    ur: 'باقی',
    hi: 'शेष',
  );
  static const showing = TranslatableString(
    en: 'Showing',
    ar: 'عرض',
    ur: 'دکھا رہا ہے',
    hi: 'दिखा रहा है',
  );
  static const of_ = TranslatableString(
    en: 'of',
    ar: 'من',
    ur: 'میں سے',
    hi: 'में से',
  );
  static const previous = TranslatableString(
    en: 'Previous',
    ar: 'السابق',
    ur: 'پچھلا',
    hi: 'पिछला',
  );
  static const next = TranslatableString(
    en: 'Next',
    ar: 'التالي',
    ur: 'اگلا',
    hi: 'अगला',
  );
  static const thisMonth = TranslatableString(
    en: 'This Month',
    ar: 'هذا الشهر',
    ur: 'اس ماہ',
    hi: 'इस महीने',
  );
  static const searchInventory = TranslatableString(
    en: 'Search inventory...',
    ar: 'ابحث في المخزون...',
    ur: 'انوینٹری تلاش کریں۔۔۔',
    hi: 'इन्वेंटरी खोजें...',
  );

  // ─── New Request / Create Material Requisition ─────────────────
  static const createMaterialRequisition = TranslatableString(
    en: 'CREATE MATERIAL REQUISITION',
    ar: 'إنشاء طلب مواد',
    ur: 'مواد کی درخواست بنائیں',
    hi: 'सामग्री मांग पत्र बनाएं',
  );
  static const createReqSubtitle = TranslatableString(
    en: 'Submit a new inventory request for your current project site.',
    ar: 'قدم طلب جرد جديد لموقع مشروعك الحالي.',
    ur: 'نئی میٹیریل کی درخواست جمع کروائیں',
    hi: 'अपनी वर्तमान परियोजना स्थल के लिए नई इन्वेंटरी अनुरोध जमा करें।',
  );
  static const selectProject = TranslatableString(
    en: 'Select Project',
    ar: 'اختر المشروع',
    ur: 'پروجیکٹ منتخب کریں',
    hi: 'परियोजना चुनें',
  );
  static const generalNotes = TranslatableString(
    en: 'General Notes',
    ar: 'ملاحظات عامة',
    ur: 'عمومی نوٹس',
    hi: 'सामान्य टिप्पणियाँ',
  );
  static const generalNotesPlaceholder = TranslatableString(
    en: 'Describe priority or special handling...',
    ar: 'صف الأولوية أو المعاملة الخاصة...',
    ur: 'ترجیح یا خاص ہدایات بیان کریں...',
    hi: 'प्राथमिकता या विशेष हैंडलिंग का वर्णन करें...',
  );
  static const generalNotesHelper = TranslatableString(
    en: 'Include any urgent site conditions or delivery restrictions.',
    ar: 'قم بتضمين أي ظروف موقع عاجلة أو قيود التسليم.',
    ur: 'ترسیل کی کسی بھی فوری شرط یا پابندی کا ذکر کریں۔',
    hi: 'किसी भी तत्काल साइट स्थिति या वितरण प्रतिबंध शामिल करें।',
  );
  static const stockAvailability = TranslatableString(
    en: 'Stock Availability',
    ar: 'توفر المخزون',
    ur: 'اسٹاک کی دستیابی',
    hi: 'स्टॉक उपलब्धता',
  );
  static const stockAvailabilityDesc = TranslatableString(
    en: 'System will automatically check central warehouse stock levels upon submission.',
    ar: 'سيقوم النظام تلقائيًا بفحص مستويات المخزون عند التقديم.',
    ur: 'سسٹم جمع کرانے پر خودکار طریقے سے مرکزی گودام کے اسٹاک کی جانچ کرے گا۔',
    hi: 'सिस्टम जमा करने पर स्वचालित रूप से केंद्रीय गोदाम स्टॉक स्तरों की जाँच करेगा।',
  );
  static const requestedItems = TranslatableString(
    en: 'Requested Items',
    ar: 'العناصر المطلوبة',
    ur: 'درخواست شدہ اشیاء',
    hi: 'अनुरोधित आइटम',
  );
  static const addNewItem = TranslatableString(
    en: 'Add New Item',
    ar: 'أضف عنصرًا جديدًا',
    ur: 'نئی چیز شامل کریں',
    hi: 'नया आइटम जोड़ें',
  );
  static const addMoreItems = TranslatableString(
    en: 'Add more items by clicking the button above.',
    ar: 'أضف المزيد من العناصر بالنقر على الزر أعلاه.',
    ur: 'اوپر والے بٹن پر کلک کر کے مزید اشیاء شامل کریں۔',
    hi: 'ऊपर के बटन पर क्लिक करके और आइटम जोड़ें।',
  );
  static const saveAsDraft = TranslatableString(
    en: 'Save as Draft',
    ar: 'حفظ كمسودة',
    ur: 'ڈرافٹ محفوظ کریں',
    hi: 'ड्राफ्ट के रूप में सहेजें',
  );
  static const action = TranslatableString(
    en: 'ACTION',
    ar: 'إجراء',
    ur: 'عمل',
    hi: 'कार्रवाई',
  );
  static const selectProjectRequired = TranslatableString(
    en: 'Please select a project',
    ar: 'يرجى اختيار مشروع',
    ur: 'براہ کرم ایک پروجیکٹ منتخب کریں',
    hi: 'कृपया एक परियोजना चुनें',
  );
  static const addAtLeastOneItem = TranslatableString(
    en: 'Please add at least one item',
    ar: 'يرجى إضافة عنصر واحد على الأقل',
    ur: 'براہ کرم کم از کم ایک آئٹم شامل کریں',
    hi: 'कृपया कम से कम एक आइटम जोड़ें',
  );
  static const browseMaterials = TranslatableString(
    en: 'Browse Materials',
    ar: 'تصفح المواد',
    ur: 'مواد دیکھیں',
    hi: 'सामग्री ब्राउज़ करें',
  );
  static const quickAction = TranslatableString(
    en: 'Quick Action',
    ar: 'إجراء سريع',
    ur: 'فوری عمل',
    hi: 'त्वरित कार्रवाई',
  );

  // ─── New Request Screen (Redesigned) ────────────────────────────
  static const newMaterialRequest = TranslatableString(
    en: 'New Material Request',
    ar: 'طلب مواد جديد',
    ur: 'میٹیریل کی نئی درخواست',
    hi: 'नई सामग्री अनुरोध',
  );
  static const selectedItems = TranslatableString(
    en: 'Selected Items',
    ar: 'العناصر المختارة',
    ur: 'منتخب اشیاء',
    hi: 'चयनित आइटम',
  );
  static const browseAndAddMore = TranslatableString(
    en: 'Browse & Add More',
    ar: 'تصفح وأضف المزيد',
    ur: 'مزید اشیاء شامل کریں',
    hi: 'ब्राउज़ करें और जोड़ें',
  );
  static const additionalNotesOptional = TranslatableString(
    en: 'Additional Notes (Optional)',
    ar: 'ملاحظات إضافية (اختياري)',
    ur: 'اضافی نوٹ (اختیاری)',
    hi: 'अतिरिक्त नोट्स (वैकल्पिक)',
  );
  static const submitRequisition = TranslatableString(
    en: 'Submit Requisition',
    ar: 'تقديم الطلب',
    ur: 'درخواست جمع کروائیں',
    hi: 'मांग पत्र जमा करें',
  );
  static const theLedger = TranslatableString(
    en: 'The Ledger',
    ar: 'دفتر الطلبات',
    ur: 'درخواست لیجر',
    hi: 'लेजर',
  );
  static const projectTag = TranslatableString(
    en: 'Project Tag',
    ar: 'علامة المشروع',
    ur: 'پروجیکٹ ٹیگ',
    hi: 'प्रोजेक्ट टैग',
  );
  static const priorityLevel = TranslatableString(
    en: 'Priority Level',
    ar: 'مستوى الأولوية',
    ur: 'ترجیحی سطح',
    hi: 'प्राथमिकता स्तर',
  );
  static const allItems = TranslatableString(
    en: 'ALL ITEMS',
    ar: 'كل العناصر',
    ur: 'تمام اشیاء',
    hi: 'सभी आइटम',
  );
  static const availableFilter = TranslatableString(
    en: 'AVAILABLE',
    ar: 'متاح',
    ur: 'دستیاب',
    hi: 'उपलब्ध',
  );
  static const lowStockFilter = TranslatableString(
    en: 'LOW STOCK',
    ar: 'مخزون منخفض',
    ur: 'کم اسٹاک',
    hi: 'कम स्टॉक',
  );
  static const searchMaterials = TranslatableString(
    en: 'Search Materials...',
    ar: 'ابحث عن المواد...',
    ur: 'اشیاء تلاش کریں...',
    hi: 'सामग्री खोजें...',
  );
  static const materialOps = TranslatableString(
    en: 'Material Ops',
    ar: 'عمليات المواد',
    ur: 'مواد آپریشنز',
    hi: 'सामग्री संचालन',
  );
  static const engineersPortal = TranslatableString(
    en: 'Engineers Portal',
    ar: 'بوابة المهندسين',
    ur: 'انجینئرز پورٹل',
    hi: 'इंजीनियर पोर्टल',
  );

  static const structure = TranslatableString(
    en: 'STRUCTURE',
    ar: 'الهيكل',
    ur: 'ساخت',
    hi: 'संरचना',
  );
  static const support = TranslatableString(
    en: 'Support',
    ar: 'الدعم',
    ur: 'مدد',
    hi: 'सहायता',
  );
  static const signOut = TranslatableString(
    en: 'Sign Out',
    ar: 'تسجيل الخروج',
    ur: 'سائن آؤٹ',
    hi: 'साइन आउट',
  );
  static const itemsSelected = TranslatableString(
    en: 'Items Selected',
    ar: 'عناصر مختارة',
    ur: 'آئٹمز منتخب',
    hi: 'आइटम चयनित',
  );
  static const normal = TranslatableString(
    en: 'Normal',
    ar: 'عادي',
    ur: 'عام',
    hi: 'सामान्य',
  );
  static const high = TranslatableString(
    en: 'High',
    ar: 'عالي',
    ur: 'زیادہ',
    hi: 'उच्च',
  );
  static const urgent = TranslatableString(
    en: 'Urgent',
    ar: 'عاجل',
    ur: 'فوری',
    hi: 'अत्यावश्यक',
  );

  // ─── Draft ──────────────────────────────────────────────────────
  static const draftSaved = TranslatableString(
    en: 'Draft saved successfully',
    ar: 'تم حفظ المسودة بنجاح',
    ur: 'ڈرافٹ کامیابی سے محفوظ ہو گیا',
    hi: 'ड्राफ्ट सफलतापूर्वक सहेजा गया',
  );
  static const statusDraft = TranslatableString(
    en: 'DRAFT',
    ar: 'مسودة',
    ur: 'مسودہ',
    hi: 'ड्राफ्ट',
  );
  static const resumeDraft = TranslatableString(
    en: 'Resume Draft',
    ar: 'استئناف المسودة',
    ur: 'ڈرافٹ جاری رکھیں',
    hi: 'ड्राफ्ट जारी रखें',
  );
  static const deleteDraft = TranslatableString(
    en: 'Delete Draft',
    ar: 'حذف المسودة',
    ur: 'ڈرافٹ حذف کریں',
    hi: 'ड्राफ्ट हटाएं',
  );
  static const draftRequests = TranslatableString(
    en: 'Drafts',
    ar: 'المسودات',
    ur: 'ڈرافٹس',
    hi: 'ड्राफ्ट',
  );
  static const requestDeletedSuccess = TranslatableString(
    en: 'Request deleted',
    ar: 'تم حذف الطلب',
    ur: 'درخواست حذف ہو گئی',
    hi: 'अनुरोध हटाया गया',
  );

  // ─── About Screen ───────────────────────────────────────────────
  static const aboutDescription = TranslatableString(
    en: 'About GodownPro',
    ar: 'حول GodownPro',
    ur: 'گوداؤن پرو کے بارے میں',
    hi: 'GodownPro के बारे में',
  );
  static const aboutBody = TranslatableString(
    en: 'GodownPro is a construction material warehouse management app built for precision. It helps site engineers, warehouse managers, and office administrators track inventory, manage material requests, and streamline operations across projects.',
    ar: 'GodownPro هو تطبيق لإدارة مستودعات مواد البناء مصمم للدقة. يساعد مهندسي الموقع ومديري المستودعات والمسؤولين في تتبع المخزون وإدارة طلبات المواد وتبسيط العمليات عبر المشاريع.',
    ur: 'گوداؤن پرو تعمیراتی مواد کے گودام کی انتظامی ایپ ہے جو درستگی کے لیے بنائی گئی ہے۔ یہ سائٹ انجینئرز، گودام مینیجرز، اور دفتری منتظمین کو انوینٹری ٹریک کرنے، مواد کی درخواستوں کا انتظام کرنے، اور پروجیکٹس کی کارروائیوں کو بہتر بنانے میں مدد کرتی ہے۔',
    hi: 'GodownPro एक निर्माण सामग्री गोदाम प्रबंधन ऐप है जो सटीकता के लिए बनाया गया है। यह साइट इंजीनियरों, गोदाम प्रबंधकों और कार्यालय प्रशासकों को इन्वेंटरी ट्रैक करने, सामग्री अनुरोध प्रबंधित करने और परियोजनाओं में संचालन सुव्यवस्थित करने में मदद करता है।',
  );
  static const aboutFramework = TranslatableString(
    en: 'Framework',
    ar: 'إطار العمل',
    ur: 'فریم ورک',
    hi: 'फ्रेमवर्क',
  );
  static const aboutDesignSystem = TranslatableString(
    en: 'Design System',
    ar: 'نظام التصميم',
    ur: 'ڈیزائن سسٹم',
    hi: 'डिज़ाइन सिस्टम',
  );
  static const aboutLanguages = TranslatableString(
    en: 'Languages',
    ar: 'اللغات',
    ur: 'زبانیں',
    hi: 'भाषाएं',
  );
  static const aboutDeveloper = TranslatableString(
    en: 'Developer',
    ar: 'المطور',
    ur: 'ڈویلپر',
    hi: 'डेवलपर',
  );
  static const privacyPolicy = TranslatableString(
    en: 'Privacy Policy',
    ar: 'سياسة الخصوصية',
    ur: 'رازداری کی پالیسی',
    hi: 'गोपनीयता नीति',
  );
  static const termsOfService = TranslatableString(
    en: 'Terms of Service',
    ar: 'شروط الخدمة',
    ur: 'سروس کی شرائط',
    hi: 'सेवा की शर्तें',
  );
  static const openSourceLicenses = TranslatableString(
    en: 'Open Source Licenses',
    ar: 'تراخيص المصادر المفتوحة',
    ur: 'اوپن سورس لائسنس',
    hi: 'ओपन सोर्स लाइसेंस',
  );
  // ─── Engineer Dashboard (Architectural Ledger) ──────────────────
  static const engineeringPrecision = TranslatableString(
    en: 'Engineering Precision',
    ar: 'الدقة الهندسية',
    ur: 'انجینئرنگ کی درستگی',
    hi: 'इंजीनियरिंग परिशुद्धता',
  );
  static const searchParameters = TranslatableString(
    en: 'Search parameters...',
    ar: 'ابحث في المعايير...',
    ur: 'سرچ پیرامیٹرز...',
    hi: 'पैरामीटर खोजें...',
  );
  static const projectSwitcher = TranslatableString(
    en: 'Project Switcher',
    ar: 'محوّل المشاريع',
    ur: 'پروجیکٹ سونچر',
    hi: 'प्रोजेक्ट स्विचर',
  );
  static const phase = TranslatableString(
    en: 'Phase',
    ar: 'مرحلة',
    ur: 'فیز',
    hi: 'चरण',
  );
  static const planReadyForApproval = TranslatableString(
    en: 'Plan ready for your approval',
    ar: 'الخطة جاهزة لموافقتك',
    ur: 'آپ کی منظوری کے لیے پلان تیار ہے',
    hi: 'योजना आपकी स्वीकृति के लिए तैयार है',
  );
  static const activeProjects = TranslatableString(
    en: 'Active projects',
    ar: 'المشاريع النشطة',
    ur: 'فعال پروجیکٹس',
    hi: 'सक्रिय परियोजनाएं',
  );
  static const actionsNeeded = TranslatableString(
    en: 'Actions needed',
    ar: 'إجراءات مطلوبة',
    ur: 'اقدامات درکار ہیں',
    hi: 'कार्रवाई आवश्यक',
  );
  static const openRequests = TranslatableString(
    en: 'Open requests',
    ar: 'طلبات مفتوحة',
    ur: 'کھلی درخواستیں',
    hi: 'खुले अनुरोध',
  );
  static const myProjects = TranslatableString(
    en: 'My projects',
    ar: 'مشاريعي',
    ur: 'میرے پروجیکٹس',
    hi: 'मेरी परियोजनाएं',
  );
  static const projects = TranslatableString(
    en: 'Projects',
    ar: 'المشاريع',
    ur: 'پروجیکٹس',
    hi: 'परियोजनाएं',
  );
  static const addAnotherProject = TranslatableString(
    en: 'Add another project',
    ar: 'إضافة مشروع آخر',
    ur: 'ایک اور پروجیکٹ شامل کریں',
    hi: 'एक और परियोजना जोड़ें',
  );
  static const createProject = TranslatableString(
    en: 'Create project',
    ar: 'إنشاء مشروع',
    ur: 'پروجیکٹ بنائیں',
    hi: 'परियोजना बनाएं',
  );
  static const projectCreated = TranslatableString(
    en: 'Project created',
    ar: 'تم إنشاء المشروع',
    ur: 'پروجیکٹ بن گیا',
    hi: 'परियोजना बनाई गई',
  );
  static const totalLabel = TranslatableString(
    en: 'total',
    ar: 'الإجمالي',
    ur: 'کل',
    hi: 'कुल',
  );
  static const filterAllShort = TranslatableString(
    en: 'All',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const filterActive = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال',
    hi: 'सक्रिय',
  );
  static const filterPlanning = TranslatableString(
    en: 'Planning',
    ar: 'تخطيط',
    ur: 'منصوبہ بندی',
    hi: 'योजना',
  );
  static const filterOnHold = TranslatableString(
    en: 'On hold',
    ar: 'متوقف',
    ur: 'رکا ہوا',
    hi: 'रुका हुआ',
  );
  static const filterCompleted = TranslatableString(
    en: 'Completed',
    ar: 'مكتمل',
    ur: 'مکمل',
    hi: 'पूर्ण',
  );
  static const approvePlan = TranslatableString(
    en: 'Approve plan',
    ar: 'الموافقة على الخطة',
    ur: 'پلان منظور کریں',
    hi: 'योजना स्वीकृत करें',
  );
  static const allDispatched = TranslatableString(
    en: 'All dispatched',
    ar: 'تم إرسال الكل',
    ur: 'سب بھیج گئے',
    hi: 'सभी भेजे गए',
  );
  static const updatedAgo = TranslatableString(
    en: 'Updated',
    ar: 'تم التحديث',
    ur: 'اپڈیٹ',
    hi: 'अपडेट',
  );
  static const materialFeed = TranslatableString(
    en: 'Material Feed',
    ar: 'تدفق المواد',
    ur: 'میٹیریل فیڈ',
    hi: 'सामग्री फ़ीड',
  );
  static const realTimeDispatches = TranslatableString(
    en: 'Real-time dispatches',
    ar: 'إرساليات فورية',
    ur: 'ریئل ٹائم ڈسپیچز',
    hi: 'रीयल-टाइम प्रेषण',
  );
  static const viewLogisticsHistory = TranslatableString(
    en: 'View Logistics History',
    ar: 'عرض سجل اللوجستيات',
    ur: 'لاجسٹکس کی تاریخ دیکھیں',
    hi: 'लॉजिस्टिक्स इतिहास देखें',
  );
  static const dispatchTo = TranslatableString(
    en: 'To',
    ar: 'إلى',
    ur: 'کی طرف',
    hi: 'को',
  );
  static const dispatchAssigned = TranslatableString(
    en: 'Assigned',
    ar: 'مُعيَّن',
    ur: 'تفویض شدہ',
    hi: 'सौंपा गया',
  );
  static const noProjectsInFilter = TranslatableString(
    en: 'No projects in this filter',
    ar: 'لا توجد مشاريع في هذا الفلتر',
    ur: 'اس فلٹر میں کوئی پروجیکٹ نہیں',
    hi: 'इस फ़िल्टर में कोई परियोजना नहीं',
  );
  static const showAll = TranslatableString(
    en: 'Show all',
    ar: 'عرض الكل',
    ur: 'سب دکھائیں',
    hi: 'सभी दिखाएं',
  );
  static const openRequestsLabel = TranslatableString(
    en: 'open requests',
    ar: 'طلبات مفتوحة',
    ur: 'کھلی درخواستیں',
    hi: 'खुले अनुरोध',
  );
  static const minuteAbbrev = TranslatableString(
    en: 'm ago',
    ar: 'د مضت',
    ur: 'منٹ پہلے',
    hi: 'मिनट पहले',
  );
  static const hourAbbrev = TranslatableString(
    en: 'h ago',
    ar: 'س مضت',
    ur: 'گھنٹے پہلے',
    hi: 'घंटे पहले',
  );
  static const dayAbbrev = TranslatableString(
    en: 'd ago',
    ar: 'ي مضت',
    ur: 'دن پہلے',
    hi: 'दिन पहले',
  );
  static const justNow = TranslatableString(
    en: 'just now',
    ar: 'الآن',
    ur: 'ابھی',
    hi: 'अभी',
  );
}

/// A translatable string with all supported language variants.
class TranslatableString {
  const TranslatableString({
    required this.en,
    required this.ar,
    required this.ur,
    required this.hi,
  });

  final String en;
  final String ar;
  final String ur;
  final String hi;

  /// English primary text.
  String get primary => en;

  /// Secondary text for current language mode.
  ///
  /// If language mode is English, we still show Arabic as secondary
  /// so UI remains English + Arabic.
  String secondary(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.english:
      case AppLanguage.arabic:
        return ar;
      case AppLanguage.urdu:
        return ur;
      case AppLanguage.hindi:
        return hi;
    }
  }
}
