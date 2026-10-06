import 'app_strings.dart';

abstract final class YorksCalculatorStrings {
  static const importAction = TranslatableString(
    en: 'Import',
    ar: 'استيراد',
    ur: 'درآمد',
    hi: 'आयात',
  );
  static const exportAction = TranslatableString(
    en: 'Export',
    ar: 'تصدير',
    ur: 'برآمد',
    hi: 'निर्यात',
  );
  static const units = TranslatableString(
    en: 'Units',
    ar: 'الوحدات',
    ur: 'اکائیاں',
    hi: 'इकाइयाँ',
  );
  static const undo = TranslatableString(
    en: 'Undo',
    ar: 'تراجع',
    ur: 'واپس کریں',
    hi: 'पूर्ववत करें',
  );
  static const redo = TranslatableString(
    en: 'Redo',
    ar: 'إعادة',
    ur: 'دوبارہ کریں',
    hi: 'फिर करें',
  );
  static const shortcuts = TranslatableString(
    en: 'Keyboard shortcuts',
    ar: 'اختصارات لوحة المفاتيح',
    ur: 'کی بورڈ شارٹ کٹس',
    hi: 'कीबोर्ड शॉर्टकट',
  );
  static const calculatorType = TranslatableString(
    en: 'Calculator type',
    ar: 'نوع الحاسبة',
    ur: 'کیلکولیٹر کی قسم',
    hi: 'कैलकुलेटर प्रकार',
  );
  static const chooseProject = TranslatableString(
    en: 'Choose a project',
    ar: 'اختر مشروعًا',
    ur: 'پروجیکٹ منتخب کریں',
    hi: 'परियोजना चुनें',
  );
  static const generalHelp = TranslatableString(
    en: 'Independent of a project',
    ar: 'مستقل عن المشروع',
    ur: 'پروجیکٹ سے الگ',
    hi: 'परियोजना से स्वतंत्र',
  );
  static const projectHelp = TranslatableString(
    en: 'Available within a project',
    ar: 'متاح ضمن مشروع',
    ur: 'پروجیکٹ کے اندر دستیاب',
    hi: 'परियोजना में उपलब्ध',
  );
  static const fileActions = TranslatableString(
    en: 'Files',
    ar: 'الملفات',
    ur: 'فائلیں',
    hi: 'फ़ाइलें',
  );
  static const importFile = TranslatableString(
    en: 'Import a JSON file',
    ar: 'استيراد ملف JSON',
    ur: 'JSON فائل درآمد کریں',
    hi: 'JSON फ़ाइल आयात करें',
  );
  static const importFileHelp = TranslatableString(
    en: 'Create a calculation from an exported Duct or ESP file. Up to 1 MB.',
    ar: 'أنشئ حسابًا من ملف Duct أو ESP مُصدّر. حتى 1 ميغابايت.',
    ur: 'برآمد شدہ ڈکٹ یا ESP فائل سے حساب بنائیں۔ 1 MB تک۔',
    hi: 'निर्यात की गई डक्ट या ESP फ़ाइल से गणना बनाएँ। 1 MB तक।',
  );
  static const deviceImportHelp = TranslatableString(
    en: 'Previous calculations are stored in this browser on this device. They are not transferred automatically from another device or browser.',
    ar: 'تُحفظ الحسابات السابقة في هذا المتصفح على هذا الجهاز. لا تُنقل تلقائيًا من جهاز أو متصفح آخر.',
    ur: 'پچھلے حساب اسی آلے کے اسی براؤزر میں محفوظ ہیں۔ دوسرے آلے یا براؤزر سے خودکار منتقل نہیں ہوتے۔',
    hi: 'पिछली गणनाएँ इसी डिवाइस के इसी ब्राउज़र में हैं। दूसरे डिवाइस या ब्राउज़र से अपने आप नहीं आतीं।',
  );
  static const noDeviceCalculations = TranslatableString(
    en: 'No previous calculations on this device',
    ar: 'لا توجد حسابات سابقة على هذا الجهاز',
    ur: 'اس آلے پر کوئی پچھلا حساب نہیں',
    hi: 'इस डिवाइस पर कोई पिछली गणना नहीं',
  );
  static const deviceUnavailable = TranslatableString(
    en: 'No saved calculation',
    ar: 'لا يوجد حساب محفوظ',
    ur: 'کوئی محفوظ حساب نہیں',
    hi: 'कोई सहेजी गणना नहीं',
  );
  static const deviceInvalid = TranslatableString(
    en: 'Saved data needs a valid JSON file',
    ar: 'تتطلب البيانات المحفوظة ملف JSON صالحًا',
    ur: 'محفوظ ڈیٹا کے لیے درست JSON فائل درکار ہے',
    hi: 'सहेजे डेटा के लिए मान्य JSON फ़ाइल चाहिए',
  );
  static const deviceReady = TranslatableString(
    en: 'Ready to import',
    ar: 'جاهز للاستيراد',
    ur: 'درآمد کے لیے تیار',
    hi: 'आयात के लिए तैयार',
  );
  static const close = TranslatableString(
    en: 'Close',
    ar: 'إغلاق',
    ur: 'بند کریں',
    hi: 'बंद करें',
  );
  static const accessHelp = TranslatableString(
    en: 'Choose who can view or edit this calculation. Project access is still required for project calculations.',
    ar: 'اختر من يمكنه عرض هذا الحساب أو تعديله. تظل صلاحية المشروع مطلوبة لحساباته.',
    ur: 'چنیں کون یہ حساب دیکھ یا بدل سکتا ہے۔ پروجیکٹ حساب کے لیے پروجیکٹ تک رسائی ضروری ہے۔',
    hi: 'चुनें कौन इस गणना को देख या संपादित कर सकता है। परियोजना गणना के लिए परियोजना पहुँच आवश्यक है।',
  );
  static const peopleWithAccess = TranslatableString(
    en: 'People with access',
    ar: 'الأشخاص المصرح لهم',
    ur: 'رسائی والے افراد',
    hi: 'पहुँच वाले लोग',
  );
  static const addPeople = TranslatableString(
    en: 'Add a person',
    ar: 'إضافة شخص',
    ur: 'فرد شامل کریں',
    hi: 'व्यक्ति जोड़ें',
  );
  static const choosePerson = TranslatableString(
    en: 'Search people',
    ar: 'البحث عن أشخاص',
    ur: 'افراد تلاش کریں',
    hi: 'लोग खोजें',
  );
  static const accessLevel = TranslatableString(
    en: 'Access level',
    ar: 'مستوى الوصول',
    ur: 'رسائی کی سطح',
    hi: 'पहुँच स्तर',
  );
  static const noSharedPeople = TranslatableString(
    en: 'No individual access grants yet',
    ar: 'لا توجد صلاحيات فردية بعد',
    ur: 'ابھی کوئی انفرادی رسائی نہیں',
    hi: 'अभी कोई व्यक्तिगत पहुँच नहीं',
  );
  static const viewHelp = TranslatableString(
    en: 'Open, export and print',
    ar: 'فتح وتصدير وطباعة',
    ur: 'کھولیں، برآمد اور پرنٹ کریں',
    hi: 'खोलें, निर्यात करें और प्रिंट करें',
  );
  static const editHelp = TranslatableString(
    en: 'Change inputs and save revisions',
    ar: 'تغيير المدخلات وحفظ الإصدارات',
    ur: 'قدریں بدلیں اور ورژن محفوظ کریں',
    hi: 'इनपुट बदलें और संशोधन सहेजें',
  );
  static const grantAccess = TranslatableString(
    en: 'Grant access',
    ar: 'منح الوصول',
    ur: 'رسائی دیں',
    hi: 'पहुँच दें',
  );
  static const accessSaved = TranslatableString(
    en: 'Access updated',
    ar: 'تم تحديث الوصول',
    ur: 'رسائی اپ ڈیٹ ہو گئی',
    hi: 'पहुँच अपडेट हुई',
  );
  static const addRow = TranslatableString(
    en: 'Add row',
    ar: 'إضافة صف',
    ur: 'قطار شامل کریں',
    hi: 'पंक्ति जोड़ें',
  );
  static const duplicateRow = TranslatableString(
    en: 'Duplicate row',
    ar: 'تكرار الصف',
    ur: 'قطار کی نقل',
    hi: 'पंक्ति की प्रतिलिपि',
  );
  static const rowShortcutHelp = TranslatableString(
    en: 'Add or duplicate below the active row.',
    ar: 'أضف أو كرر أسفل الصف النشط.',
    ur: 'فعال قطار کے نیچے شامل کریں یا نقل بنائیں۔',
    hi: 'सक्रिय पंक्ति के नीचे जोड़ें या प्रतिलिपि बनाएँ।',
  );
  static const replaceInputs = TranslatableString(
    en: 'Replace current inputs?',
    ar: 'استبدال المدخلات الحالية؟',
    ur: 'موجودہ قدریں بدلیں؟',
    hi: 'वर्तमान इनपुट बदलें?',
  );
  static const replaceHelp = TranslatableString(
    en: 'Import replaces the current inputs. You can undo it before saving.',
    ar: 'يستبدل الاستيراد المدخلات الحالية. يمكنك التراجع قبل الحفظ.',
    ur: 'درآمد موجودہ قدریں بدل دے گی۔ محفوظ کرنے سے پہلے واپس کر سکتے ہیں۔',
    hi: 'आयात वर्तमान इनपुट बदलता है। सहेजने से पहले पूर्ववत कर सकते हैं।',
  );
  static const start = TranslatableString(
    en: 'Start a calculation',
    ar: 'ابدأ حسابًا',
    ur: 'حساب شروع کریں',
    hi: 'गणना शुरू करें',
  );
  static const ductHelp = TranslatableString(
    en: 'Size a duct, check airflow and review pressure loss.',
    ar: 'حدد مقاس مجرى الهواء وافحص التدفق وفقد الضغط.',
    ur: 'ڈکٹ کا سائز، ہوا کا بہاؤ اور دباؤ کا نقصان جانچیں۔',
    hi: 'डक्ट का आकार, वायु प्रवाह और दबाव हानि जाँचें।',
  );
  static const espHelp = TranslatableString(
    en: 'Build a system calculation with ducts and fittings.',
    ar: 'أنشئ حساب النظام باستخدام مجاري الهواء والوصلات.',
    ur: 'ڈکٹس اور فٹنگز کے ساتھ نظام کا حساب بنائیں۔',
    hi: 'डक्ट और फिटिंग के साथ सिस्टम गणना बनाएँ।',
  );
  static const allScopes = TranslatableString(
    en: 'All scopes',
    ar: 'كل النطاقات',
    ur: 'تمام دائرے',
    hi: 'सभी दायरे',
  );
  static const active = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال',
    hi: 'सक्रिय',
  );
  static const actions = TranslatableString(
    en: 'Calculation actions',
    ar: 'إجراءات الحساب',
    ur: 'حساب کے اعمال',
    hi: 'गणना कार्रवाइयाँ',
  );
  static const clearFilters = TranslatableString(
    en: 'Clear filters',
    ar: 'مسح عوامل التصفية',
    ur: 'فلٹرز صاف کریں',
    hi: 'फ़िल्टर साफ़ करें',
  );
  static const filteredHelp = TranslatableString(
    en: 'Try a different name or change the filters.',
    ar: 'جرّب اسمًا آخر أو غيّر عوامل التصفية.',
    ur: 'دوسرا نام آزمائیں یا فلٹرز تبدیل کریں۔',
    hi: 'दूसरा नाम आज़माएँ या फ़िल्टर बदलें।',
  );
  static const systemDetails = TranslatableString(
    en: 'System details',
    ar: 'تفاصيل النظام',
    ur: 'نظام کی تفصیلات',
    hi: 'सिस्टम विवरण',
  );
  static const pressureLoss = TranslatableString(
    en: 'Pressure loss',
    ar: 'فقد الضغط',
    ur: 'دباؤ کا نقصان',
    hi: 'दबाव हानि',
  );

  static const invalidInputs = TranslatableString(
    en: 'Enter valid non-negative numbers before saving.',
    ar: 'أدخل أرقامًا صحيحة غير سالبة قبل الحفظ.',
    ur: 'محفوظ کرنے سے پہلے درست غیر منفی اعداد درج کریں۔',
    hi: 'सहेजने से पहले मान्य गैर ऋणात्मक संख्याएँ दर्ज करें।',
  );
  static const fittings = TranslatableString(
    en: 'Fitting library',
    ar: 'مكتبة الوصلات',
    ur: 'فٹنگ لائبریری',
    hi: 'फिटिंग संग्रह',
  );
  static const designBasis = TranslatableString(
    en: 'Design basis',
    ar: 'أساس التصميم',
    ur: 'ڈیزائن کی بنیاد',
    hi: 'डिज़ाइन आधार',
  );
  static const method = TranslatableString(
    en: 'Sizing method',
    ar: 'طريقة تحديد المقاس',
    ur: 'سائز کا طریقہ',
    hi: 'आकार विधि',
  );
  static const checkSize = TranslatableString(
    en: 'Check size',
    ar: 'فحص المقاس',
    ur: 'سائز جانچیں',
    hi: 'आकार जाँचें',
  );
  static const byVelocity = TranslatableString(
    en: 'Size by velocity',
    ar: 'تحديد المقاس بالسرعة',
    ur: 'رفتار کے مطابق سائز',
    hi: 'वेग से आकार',
  );
  static const byFriction = TranslatableString(
    en: 'Size by friction',
    ar: 'تحديد المقاس بالاحتكاك',
    ur: 'رگڑ کے مطابق سائز',
    hi: 'घर्षण से आकार',
  );
  static const equivalent = TranslatableString(
    en: 'Equivalent diameter',
    ar: 'القطر المكافئ',
    ur: 'مساوی قطر',
    hi: 'समतुल्य व्यास',
  );

  static const row = TranslatableString(
    en: 'Edit row',
    ar: 'تعديل الصف',
    ur: 'قطار میں ترمیم',
    hi: 'पंक्ति संपादित करें',
  );
  static const leavePending = TranslatableString(
    en: 'Leave and keep recovery',
    ar: 'مغادرة والاحتفاظ بالاسترداد',
    ur: 'بازیابی محفوظ رکھ کر نکلیں',
    hi: 'पुनर्प्राप्ति रखकर छोड़ें',
  );

  static const calculators = TranslatableString(
    en: 'Calculators',
    ar: 'الحاسبات',
    ur: 'کیلکولیٹرز',
    hi: 'कैलकुलेटर',
  );
  static const newCalculation = TranslatableString(
    en: 'New calculation',
    ar: 'حساب جديد',
    ur: 'نیا حساب',
    hi: 'नई गणना',
  );
  static const subtitle = TranslatableString(
    en: 'One workspace for duct sizing and external static pressure.',
    ar: 'مساحة واحدة لحساب مقاسات مجاري الهواء والضغط الساكن الخارجي.',
    ur: 'ڈکٹ سائز اور بیرونی جامد دباؤ کے لیے ایک جگہ۔',
    hi: 'डक्ट आकार और बाहरी स्थिर दबाव के लिए एक कार्यक्षेत्र।',
  );
  static const all = TranslatableString(
    en: 'All calculations',
    ar: 'كل الحسابات',
    ur: 'تمام حسابات',
    hi: 'सभी गणनाएँ',
  );
  static const duct = TranslatableString(
    en: 'Duct Sizer',
    ar: 'حاسبة مجرى الهواء',
    ur: 'ڈکٹ سائزنگ',
    hi: 'डक्ट साइज़र',
  );
  static const esp = TranslatableString(
    en: 'ESP Calculator',
    ar: 'حاسبة الضغط الساكن الخارجي',
    ur: 'ESP کیلکولیٹر',
    hi: 'ESP कैलकुलेटर',
  );
  static const general = TranslatableString(
    en: 'General',
    ar: 'عام',
    ur: 'عمومی',
    hi: 'सामान्य',
  );
  static const project = TranslatableString(
    en: 'Project',
    ar: 'المشروع',
    ur: 'پروجیکٹ',
    hi: 'परियोजना',
  );
  static const recent = TranslatableString(
    en: 'Recent calculations',
    ar: 'الحسابات الأخيرة',
    ur: 'حالیہ حسابات',
    hi: 'हाल की गणनाएँ',
  );
  static const search = TranslatableString(
    en: 'Search calculations',
    ar: 'البحث في الحسابات',
    ur: 'حسابات تلاش کریں',
    hi: 'गणनाएँ खोजें',
  );
  static const empty = TranslatableString(
    en: 'No calculations yet',
    ar: 'لا توجد حسابات بعد',
    ur: 'ابھی کوئی حساب نہیں',
    hi: 'अभी कोई गणना नहीं',
  );
  static const emptyHelp = TranslatableString(
    en: 'Create a calculation or import a saved file to get started.',
    ar: 'أنشئ حسابًا أو استورد ملفًا محفوظًا للبدء.',
    ur: 'شروع کرنے کے لیے حساب بنائیں یا محفوظ فائل درآمد کریں۔',
    hi: 'शुरू करने के लिए गणना बनाएँ या सहेजी फ़ाइल आयात करें।',
  );
  static const noResults = TranslatableString(
    en: 'No matching calculations',
    ar: 'لا توجد حسابات مطابقة',
    ur: 'کوئی مماثل حساب نہیں',
    hi: 'कोई मिलती गणना नहीं',
  );
  static const name = TranslatableString(
    en: 'Calculation name',
    ar: 'اسم الحساب',
    ur: 'حساب کا نام',
    hi: 'गणना का नाम',
  );
  static const scope = TranslatableString(
    en: 'Scope',
    ar: 'النطاق',
    ur: 'دائرہ',
    hi: 'दायरा',
  );
  static const create = TranslatableString(
    en: 'Create calculation',
    ar: 'إنشاء حساب',
    ur: 'حساب بنائیں',
    hi: 'गणना बनाएँ',
  );
  static const cancel = TranslatableString(
    en: 'Cancel',
    ar: 'إلغاء',
    ur: 'منسوخ',
    hi: 'रद्द करें',
  );
  static const save = TranslatableString(
    en: 'Save',
    ar: 'حفظ',
    ur: 'محفوظ کریں',
    hi: 'सहेजें',
  );
  static const saving = TranslatableString(
    en: 'Saving…',
    ar: 'جارٍ الحفظ…',
    ur: 'محفوظ ہو رہا ہے…',
    hi: 'सहेजा जा रहा है…',
  );
  static const saved = TranslatableString(
    en: 'Saved',
    ar: 'محفوظ',
    ur: 'محفوظ',
    hi: 'सहेजा गया',
  );
  static const unsaved = TranslatableString(
    en: 'Unsaved changes',
    ar: 'تغييرات غير محفوظة',
    ur: 'غیر محفوظ تبدیلیاں',
    hi: 'बिना सहेजे बदलाव',
  );
  static const viewOnly = TranslatableString(
    en: 'View only',
    ar: 'عرض فقط',
    ur: 'صرف دیکھیں',
    hi: 'केवल देखें',
  );
  static const edit = TranslatableString(
    en: 'Can edit',
    ar: 'يمكن التعديل',
    ur: 'ترمیم کر سکتے ہیں',
    hi: 'संपादन कर सकते हैं',
  );
  static const share = TranslatableString(
    en: 'Share',
    ar: 'مشاركة',
    ur: 'اشتراک',
    hi: 'साझा करें',
  );
  static const access = TranslatableString(
    en: 'Manage access',
    ar: 'إدارة الوصول',
    ur: 'رسائی کا انتظام',
    hi: 'पहुँच प्रबंधित करें',
  );
  static const person = TranslatableString(
    en: 'Person',
    ar: 'الشخص',
    ur: 'شخص',
    hi: 'व्यक्ति',
  );
  static const view = TranslatableString(
    en: 'Can view',
    ar: 'يمكن العرض',
    ur: 'دیکھ سکتے ہیں',
    hi: 'देख सकते हैं',
  );
  static const remove = TranslatableString(
    en: 'Remove access',
    ar: 'إزالة الوصول',
    ur: 'رسائی ہٹائیں',
    hi: 'पहुँच हटाएँ',
  );
  static const apply = TranslatableString(
    en: 'Apply',
    ar: 'تطبيق',
    ur: 'لاگو کریں',
    hi: 'लागू करें',
  );
  static const sharingHelp = TranslatableString(
    en: 'Managers control sharing. Project calculations also require access to that project.',
    ar: 'يتحكم المسؤولون بالمشاركة. تتطلب حسابات المشروع صلاحية الوصول إليه أيضًا.',
    ur: 'منتظمین اشتراک کنٹرول کرتے ہیں۔ پروجیکٹ حساب کے لیے اس پروجیکٹ تک رسائی بھی ضروری ہے۔',
    hi: 'प्रबंधक साझाकरण नियंत्रित करते हैं। परियोजना गणना के लिए उस परियोजना की पहुँच भी आवश्यक है।',
  );
  static const import = TranslatableString(
    en: 'Import JSON',
    ar: 'استيراد JSON',
    ur: 'JSON درآمد کریں',
    hi: 'JSON आयात करें',
  );
  static const export = TranslatableString(
    en: 'Export JSON',
    ar: 'تصدير JSON',
    ur: 'JSON برآمد کریں',
    hi: 'JSON निर्यात करें',
  );
  static const print = TranslatableString(
    en: 'Print / PDF',
    ar: 'طباعة / PDF',
    ur: 'پرنٹ / PDF',
    hi: 'प्रिंट / PDF',
  );
  static const archive = TranslatableString(
    en: 'Archive',
    ar: 'أرشفة',
    ur: 'محفوظات میں ڈالیں',
    hi: 'संग्रहीत करें',
  );
  static const archived = TranslatableString(
    en: 'Archived',
    ar: 'مؤرشف',
    ur: 'محفوظات',
    hi: 'संग्रहीत',
  );
  static const projectArchived = TranslatableString(
    en: 'This project is archived. You can view, export or print saved calculations, but cannot save changes to this project.',
    ar: 'هذا المشروع مؤرشف. يمكنك عرض الحسابات المحفوظة أو تصديرها أو طباعتها، لكن لا يمكنك حفظ تغييرات في هذا المشروع.',
    ur: 'یہ پروجیکٹ محفوظات میں ہے۔ آپ محفوظ حساب دیکھ، برآمد یا پرنٹ کر سکتے ہیں، لیکن اس پروجیکٹ میں تبدیلیاں محفوظ نہیں کر سکتے۔',
    hi: 'यह परियोजना संग्रहीत है। आप सहेजी गई गणनाएँ देख, निर्यात या प्रिंट कर सकते हैं, लेकिन इस परियोजना में बदलाव सहेज नहीं सकते।',
  );
  static const restore = TranslatableString(
    en: 'Restore',
    ar: 'استعادة',
    ur: 'بحال کریں',
    hi: 'पुनर्स्थापित करें',
  );
  static const refresh = TranslatableString(
    en: 'Refresh',
    ar: 'تحديث',
    ur: 'تازہ کریں',
    hi: 'रीफ़्रेश करें',
  );
  static const more = TranslatableString(
    en: 'Load more',
    ar: 'تحميل المزيد',
    ur: 'مزید لوڈ کریں',
    hi: 'और लोड करें',
  );
  static const back = TranslatableString(
    en: 'Calculators',
    ar: 'الحاسبات',
    ur: 'کیلکولیٹرز',
    hi: 'कैलकुलेटर',
  );
  static const leave = TranslatableString(
    en: 'Leave without saving?',
    ar: 'المغادرة دون حفظ؟',
    ur: 'محفوظ کیے بغیر نکلیں؟',
    hi: 'बिना सहेजे छोड़ें?',
  );
  static const leaveHelp = TranslatableString(
    en: 'Your latest changes have not been saved.',
    ar: 'لم يتم حفظ تغييراتك الأخيرة.',
    ur: 'آپ کی تازہ تبدیلیاں محفوظ نہیں ہیں۔',
    hi: 'आपके नवीनतम बदलाव सहेजे नहीं गए हैं।',
  );
  static const discard = TranslatableString(
    en: 'Discard changes',
    ar: 'تجاهل التغييرات',
    ur: 'تبدیلیاں چھوڑ دیں',
    hi: 'बदलाव छोड़ें',
  );
  static const stay = TranslatableString(
    en: 'Keep editing',
    ar: 'متابعة التعديل',
    ur: 'ترمیم جاری رکھیں',
    hi: 'संपादन जारी रखें',
  );
  static const error = TranslatableString(
    en: 'Could not complete this action. Check your connection and try again.',
    ar: 'تعذر إتمام الإجراء. تحقق من الاتصال وحاول مجددًا.',
    ur: 'یہ عمل مکمل نہیں ہوا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
    hi: 'यह कार्रवाई पूरी नहीं हुई। कनेक्शन जाँचें और फिर प्रयास करें।',
  );
  static const conflict = TranslatableString(
    en: 'Someone saved a newer revision. Export your changes, then reopen the latest calculation.',
    ar: 'حفظ شخص آخر إصدارًا أحدث. صدّر تغييراتك ثم افتح أحدث حساب.',
    ur: 'کسی نے نیا ورژن محفوظ کیا۔ تبدیلیاں برآمد کریں پھر تازہ حساب کھولیں۔',
    hi: 'किसी ने नया संशोधन सहेजा है। बदलाव निर्यात करें और नवीनतम गणना खोलें।',
  );
  static const denied = TranslatableString(
    en: 'This calculation is no longer available to you.',
    ar: 'لم يعد هذا الحساب متاحًا لك.',
    ur: 'یہ حساب اب آپ کے لیے دستیاب نہیں۔',
    hi: 'यह गणना अब आपके लिए उपलब्ध नहीं है।',
  );
  static const retry = TranslatableString(
    en: 'Retry save',
    ar: 'إعادة محاولة الحفظ',
    ur: 'دوبارہ محفوظ کریں',
    hi: 'फिर सहेजें',
  );
  static const pending = TranslatableString(
    en: 'Save not confirmed. Retry to confirm the same changes.',
    ar: 'لم يتم تأكيد الحفظ. أعد المحاولة لتأكيد نفس التغييرات.',
    ur: 'محفوظ ہونے کی تصدیق نہیں ہوئی۔ انہی تبدیلیوں کے لیے دوبارہ کوشش کریں۔',
    hi: 'सहेजने की पुष्टि नहीं हुई। उन्हीं बदलावों की पुष्टि के लिए फिर प्रयास करें।',
  );
  static const invalidFile = TranslatableString(
    en: 'This file is not a supported calculation. Use a valid Duct Sizer or ESP JSON file up to 1 MB.',
    ar: 'هذا الملف ليس حسابًا مدعومًا. استخدم ملف JSON صالحًا حتى 1 ميغابايت.',
    ur: 'یہ فائل معاون حساب نہیں۔ 1 MB تک درست ڈکٹ یا ESP JSON فائل استعمال کریں۔',
    hi: 'यह फ़ाइल समर्थित गणना नहीं है। 1 MB तक मान्य डक्ट या ESP JSON फ़ाइल चुनें।',
  );
  static const legacy = TranslatableString(
    en: 'Import previous device calculation',
    ar: 'استيراد حساب الجهاز السابق',
    ur: 'پچھلا مقامی حساب درآمد کریں',
    hi: 'पिछली डिवाइस गणना आयात करें',
  );
  static const revision = TranslatableString(
    en: 'Revision',
    ar: 'الإصدار',
    ur: 'ورژن',
    hi: 'संशोधन',
  );
  static const updated = TranslatableString(
    en: 'Updated',
    ar: 'آخر تحديث',
    ur: 'اپ ڈیٹ',
    hi: 'अद्यतन',
  );
  static const owner = TranslatableString(
    en: 'Owner',
    ar: 'المالك',
    ur: 'مالک',
    hi: 'स्वामी',
  );
  static const startHelp = TranslatableString(
    en: 'Name this calculation and choose where it belongs.',
    ar: 'سمّ هذا الحساب وحدد نطاقه.',
    ur: 'حساب کو نام دیں اور اس کا دائرہ منتخب کریں۔',
    hi: 'गणना को नाम दें और उसका दायरा चुनें।',
  );
  static const archiveHelp = TranslatableString(
    en: 'The calculation will stay available in Archived.',
    ar: 'سيظل الحساب متاحًا ضمن المؤرشف.',
    ur: 'حساب محفوظات میں دستیاب رہے گا۔',
    hi: 'गणना संग्रहीत में उपलब्ध रहेगी।',
  );
  static const confirm = TranslatableString(
    en: 'Confirm',
    ar: 'تأكيد',
    ur: 'تصدیق',
    hi: 'पुष्टि करें',
  );
  static const newDraft = TranslatableString(
    en: 'New calculation',
    ar: 'حساب جديد',
    ur: 'نیا حساب',
    hi: 'नई गणना',
  );
}
