import 'app_strings.dart';

/// Centralized, bilingual-capable copy for the Yorks V1 BOQ workspace.
abstract final class YorksV1BoqStrings {
  static const serialNumber = TranslatableString(
    en: 'S:No',
    ar: 'م',
    ur: 'نمبر',
    hi: 'क्र.',
  );
  static const boq = TranslatableString(
    en: 'Bill of quantities',
    ar: 'جدول الكميات',
    ur: 'بل آف کوانٹٹیز',
    hi: 'मात्रा विवरण',
  );
  static const boqDescription = TranslatableString(
    en: 'Organise each project worksheet, then edit material rows directly.',
    ar: 'نظّم كل ورقة عمل للمشروع ثم عدّل صفوف المواد مباشرة.',
    ur: 'ہر پراجیکٹ ورک شیٹ منظم کریں اور میٹریل قطاریں براہ راست ایڈٹ کریں۔',
    hi: 'प्रोजेक्ट वर्कशीट व्यवस्थित करें और सामग्री पंक्तियाँ सीधे संपादित करें।',
  );
  static const worksheets = TranslatableString(
    en: 'BOQ worksheets',
    ar: 'أوراق عمل جدول الكميات',
    ur: 'BOQ ورک شیٹس',
    hi: 'BOQ वर्कशीट',
  );
  static const scope = TranslatableString(
    en: 'BOQ scope',
    ar: 'نطاق جدول الكميات',
    ur: 'BOQ اسکوپ',
    hi: 'BOQ स्कोप',
  );
  static const allScopes = TranslatableString(
    en: 'All',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const allScopesDescription = TranslatableString(
    en: 'Read-only aggregate of Common and every building. Choose one scope to edit, export or create a material request source.',
    ar: 'عرض مجمع للقراءة فقط للنطاق المشترك وجميع المباني. اختر نطاقاً واحداً للتعديل أو التصدير أو إنشاء مصدر لطلب مواد.',
    ur: 'کامن اور ہر بلڈنگ کا صرف پڑھنے کے لیے مجموعی منظر۔ ایڈٹ، ایکسپورٹ یا میٹریل ریکویسٹ سورس کے لیے ایک اسکوپ منتخب کریں۔',
    hi: 'कॉमन और हर बिल्डिंग का केवल-पढ़ने योग्य समेकित दृश्य। संपादन, निर्यात या सामग्री अनुरोध स्रोत के लिए एक स्कोप चुनें।',
  );
  static const overviewDescription = TranslatableString(
    en: 'Project overview only. Each Common/building BOQ remains independent and keeps its own folders, rows, imports and material requests.',
    ar: 'نظرة عامة للمشروع فقط. يظل كل جدول كميات مشترك/مبنى مستقلاً ويحتفظ بمجلداته وصفوفه ووارداته وطلبات مواده الخاصة.',
    ur: 'صرف پراجیکٹ اوورویو۔ ہر کامن/بلڈنگ BOQ آزاد رہتا ہے اور اپنے فولڈرز، قطاریں، امپورٹس اور میٹیریل ریکویسٹس رکھتا ہے۔',
    hi: 'केवल प्रोजेक्ट अवलोकन। प्रत्येक कॉमन/बिल्डिंग BOQ स्वतंत्र रहता है और अपने फ़ोल्डर, पंक्तियाँ, आयात और सामग्री अनुरोध रखता है।',
  );
  static const folders = TranslatableString(
    en: 'Folders',
    ar: 'المجلدات',
    ur: 'فولڈرز',
    hi: 'फ़ोल्डर',
  );
  static const startedFolders = TranslatableString(
    en: 'Started',
    ar: 'بدأت',
    ur: 'شروع شدہ',
    hi: 'प्रारंभ किए गए',
  );
  static const materials = TranslatableString(
    en: 'Materials',
    ar: 'المواد',
    ur: 'میٹیریلز',
    hi: 'सामग्री',
  );
  static const openScope = TranslatableString(
    en: 'Open scope',
    ar: 'فتح النطاق',
    ur: 'اسکوپ کھولیں',
    hi: 'स्कोप खोलें',
  );
  static const legacyBoqs = TranslatableString(
    en: 'Legacy BOQs needing scope assignment',
    ar: 'جداول كميات قديمة تحتاج تعيين النطاق',
    ur: 'اسکوپ اسائنمنٹ کی ضرورت والے لیگیسی BOQs',
    hi: 'स्कोप असाइनमेंट आवश्यक वाले लीगेसी BOQ',
  );
  static const legacyUnassigned = TranslatableString(
    en: 'Legacy BOQ — scope assignment required',
    ar: 'جدول كميات قديم — يلزم تعيين النطاق',
    ur: 'لیگیسی BOQ — اسکوپ اسائنمنٹ درکار ہے',
    hi: 'लीगेसी BOQ — स्कोप असाइनमेंट आवश्यक है',
  );
  static const assignLegacyScope = TranslatableString(
    en: 'Assign BOQ scope',
    ar: 'تعيين نطاق جدول الكميات',
    ur: 'BOQ اسکوپ اسائن کریں',
    hi: 'BOQ स्कोप असाइन करें',
  );
  static const assignLegacyScopeDescription = TranslatableString(
    en: 'Choose the one real Common or building scope that owns this preserved BOQ. This cannot rewrite submitted request history.',
    ar: 'اختر النطاق الحقيقي الوحيد المشترك أو المبنى الذي يملك جدول الكميات المحفوظ. لا يمكن لهذا إعادة كتابة سجل الطلبات المُرسلة.',
    ur: 'وہ ایک اصلی کامن یا بلڈنگ اسکوپ منتخب کریں جس کا یہ محفوظ BOQ ہے۔ یہ جمع شدہ ریکویسٹ ہسٹری کو دوبارہ نہیں لکھ سکتا۔',
    hi: 'वह एक वास्तविक कॉमन या बिल्डिंग स्कोप चुनें जिसका यह संरक्षित BOQ है। यह सबमिट किए गए अनुरोध इतिहास को नहीं बदलेगा।',
  );
  static const scopedWorksheet = TranslatableString(
    en: 'Scope: {scope}',
    ar: 'النطاق: {scope}',
    ur: 'اسکوپ: {scope}',
    hi: 'स्कोप: {scope}',
  );
  static const addGroup = TranslatableString(
    en: 'Add custom group',
    ar: 'إضافة مجموعة مخصصة',
    ur: 'کسٹم گروپ شامل کریں',
    hi: 'कस्टम समूह जोड़ें',
  );
  static const newGroup = TranslatableString(
    en: 'New Group',
    ar: 'مجموعة جديدة',
    ur: 'نیا گروپ',
    hi: 'नया समूह',
  );
  static const customGroupName = TranslatableString(
    en: 'Custom group name',
    ar: 'اسم المجموعة المخصصة',
    ur: 'کسٹم گروپ کا نام',
    hi: 'कस्टम समूह का नाम',
  );
  static const noGroups = TranslatableString(
    en: 'No BOQ worksheets are available for this project.',
    ar: 'لا توجد أوراق عمل جدول كميات متاحة لهذا المشروع.',
    ur: 'اس پراجیکٹ کے لیے کوئی BOQ ورک شیٹ دستیاب نہیں ہے۔',
    hi: 'इस प्रोजेक्ट के लिए कोई BOQ वर्कशीट उपलब्ध नहीं है।',
  );
  static const worksheet = TranslatableString(
    en: 'Worksheet',
    ar: 'ورقة العمل',
    ur: 'ورک شیٹ',
    hi: 'वर्कशीट',
  );
  static const worksheetTitle = TranslatableString(
    en: 'Worksheet title',
    ar: 'عنوان ورقة العمل',
    ur: 'ورک شیٹ کا عنوان',
    hi: 'वर्कशीट शीर्षक',
  );
  static const rows = TranslatableString(
    en: 'rows',
    ar: 'صفوف',
    ur: 'قطاریں',
    hi: 'पंक्तियाँ',
  );
  static const columns = TranslatableString(
    en: 'columns',
    ar: 'أعمدة',
    ur: 'کالم',
    hi: 'कॉलम',
  );
  static const defaultGroup = TranslatableString(
    en: 'Standard group',
    ar: 'مجموعة قياسية',
    ur: 'معیاری گروپ',
    hi: 'मानक समूह',
  );
  static const customGroup = TranslatableString(
    en: 'Custom group',
    ar: 'مجموعة مخصصة',
    ur: 'کسٹم گروپ',
    hi: 'कस्टम समूह',
  );
  static const addColumn = TranslatableString(
    en: 'Add column',
    ar: 'إضافة عمود',
    ur: 'کالم شامل کریں',
    hi: 'कॉलम जोड़ें',
  );
  static const columnHeading = TranslatableString(
    en: 'Column heading',
    ar: 'عنوان العمود',
    ur: 'کالم ہیڈنگ',
    hi: 'कॉलम शीर्षक',
  );
  static const blankRow = TranslatableString(
    en: 'Blank row',
    ar: 'صف فارغ',
    ur: 'خالی قطار',
    hi: 'खाली पंक्ति',
  );
  static const addFirstRow = TranslatableString(
    en: 'Add First Row',
    ar: 'إضافة الصف الأول',
    ur: 'پہلی قطار شامل کریں',
    hi: 'पहली पंक्ति जोड़ें',
  );
  static const similarRow = TranslatableString(
    en: 'Similar row',
    ar: 'صف مماثل',
    ur: 'مشابہ قطار',
    hi: 'समान पंक्ति',
  );
  static const createRequestFromFolder = TranslatableString(
    en: 'Use entire folder for a material request',
    ar: 'استخدم المجلد بالكامل لطلب مواد',
    ur: 'پورا فولڈر میٹریل ریکویسٹ کے لیے استعمال کریں',
    hi: 'पूरे फ़ोल्डर से सामग्री अनुरोध बनाएँ',
  );
  static const sendWholeGroup = TranslatableString(
    en: 'Send Whole Group',
    ar: 'إرسال المجموعة كاملة',
    ur: 'پورا گروپ بھیجیں',
    hi: 'पूरा समूह भेजें',
  );
  static const createRequestFromFolderDescription = TranslatableString(
    en: 'Copies every BOQ row into a private draft. Review it before submitting to Procurement.',
    ar: 'ينسخ كل صفوف جدول الكميات إلى مسودة خاصة. راجعها قبل إرسالها إلى المشتريات.',
    ur: 'ہر BOQ قطار کو نجی ڈرافٹ میں کاپی کرتا ہے۔ پروکیورمنٹ کو بھیجنے سے پہلے جائزہ لیں۔',
    hi: 'हर BOQ पंक्ति को निजी ड्राफ्ट में कॉपी करता है। प्रोक्योरमेंट को भेजने से पहले समीक्षा करें।',
  );
  static const save = TranslatableString(
    en: 'Save',
    ar: 'حفظ',
    ur: 'محفوظ کریں',
    hi: 'सहेजें',
  );
  static const saved = TranslatableString(
    en: 'Saved',
    ar: 'تم الحفظ',
    ur: 'محفوظ ہو گیا',
    hi: 'सहेजा गया',
  );
  static const saving = TranslatableString(
    en: 'Saving…',
    ar: 'جارٍ الحفظ…',
    ur: 'محفوظ ہو رہا ہے…',
    hi: 'सहेजा जा रहा है…',
  );
  static const unsavedChanges = TranslatableString(
    en: 'Unsaved changes',
    ar: 'تغييرات غير محفوظة',
    ur: 'غیر محفوظ تبدیلیاں',
    hi: 'असहेजे परिवर्तन',
  );
  static const syncConflict = TranslatableString(
    en: 'This worksheet changed elsewhere. Refresh to review the latest version.',
    ar: 'تغيرت ورقة العمل هذه في مكان آخر. حدّث لمراجعة أحدث إصدار.',
    ur: 'یہ ورک شیٹ کہیں اور تبدیل ہوئی ہے۔ تازہ ترین ورژن دیکھنے کے لیے ریفریش کریں۔',
    hi: 'यह वर्कशीट कहीं और बदल गई है। नवीनतम संस्करण देखने के लिए रीफ़्रेश करें।',
  );
  static const refresh = TranslatableString(
    en: 'Refresh',
    ar: 'تحديث',
    ur: 'ریفریش',
    hi: 'रीफ़्रेश',
  );
  static const readOnly = TranslatableString(
    en: 'Read only',
    ar: 'للقراءة فقط',
    ur: 'صرف پڑھنے کے لیے',
    hi: 'केवल पढ़ने के लिए',
  );
  static const readOnlyDescription = TranslatableString(
    en: 'Procurement can review the worksheet but cannot change its groups, columns or rows.',
    ar: 'يمكن للمشتريات مراجعة ورقة العمل ولكن لا يمكنها تغيير مجموعاتها أو أعمدتها أو صفوفها.',
    ur: 'پروکیورمنٹ ورک شیٹ کا جائزہ لے سکتا ہے مگر اس کے گروپ، کالم یا قطاریں تبدیل نہیں کر سکتا۔',
    hi: 'प्रोक्योरमेंट वर्कशीट की समीक्षा कर सकता है, पर उसके समूह, कॉलम या पंक्तियाँ नहीं बदल सकता।',
  );
  static const mobileEditor = TranslatableString(
    en: 'Edit row',
    ar: 'تعديل الصف',
    ur: 'قطار ایڈٹ کریں',
    hi: 'पंक्ति संपादित करें',
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
  static const deleteColumn = TranslatableString(
    en: 'Delete column',
    ar: 'حذف العمود',
    ur: 'کالم حذف کریں',
    hi: 'कॉलम हटाएँ',
  );
  static const deleteColumnConfirmation = TranslatableString(
    en: 'Delete this populated column? Its legacy values stay in the audited worksheet history.',
    ar: 'هل تريد حذف هذا العمود المعبأ؟ تبقى قيمه السابقة في سجل ورقة العمل المدقق.',
    ur: 'کیا اس بھرے ہوئے کالم کو حذف کریں؟ اس کی پرانی ویلیوز آڈٹ شدہ ورک شیٹ ہسٹری میں رہیں گی۔',
    hi: 'क्या इस भरे कॉलम को हटाना है? इसके पुराने मान ऑडिटेड वर्कशीट इतिहास में रहेंगे।',
  );
  static const archiveGroup = TranslatableString(
    en: 'Archive group',
    ar: 'أرشفة المجموعة',
    ur: 'گروپ آرکائیو کریں',
    hi: 'समूह आर्काइव करें',
  );
  static const archived = TranslatableString(
    en: 'Archived',
    ar: 'مؤرشف',
    ur: 'آرکائیو شدہ',
    hi: 'आर्काइव किया गया',
  );
  static const deleteRow = TranslatableString(
    en: 'Delete row',
    ar: 'حذف الصف',
    ur: 'قطار حذف کریں',
    hi: 'पंक्ति हटाएँ',
  );
  static const deleteRowConfirmation = TranslatableString(
    en: 'Delete this populated row? Its values remain in the audited worksheet history.',
    ar: 'هل تريد حذف هذا الصف المعبأ؟ تبقى قيمه في سجل ورقة العمل المدقق.',
    ur: 'کیا اس بھرے ہوئے قطار کو حذف کریں؟ اس کی ویلیوز آڈٹ شدہ ورک شیٹ ہسٹری میں رہیں گی۔',
    hi: 'क्या इस भरी हुई पंक्ति को हटाना है? इसके मान ऑडिटेड वर्कशीट इतिहास में रहेंगे।',
  );
  static const noRows = TranslatableString(
    en: 'No rows yet. Add a column, then start the worksheet with a blank row.',
    ar: 'لا توجد صفوف بعد. أضف عموداً ثم ابدأ ورقة العمل بصف فارغ.',
    ur: 'ابھی کوئی قطار نہیں۔ کالم شامل کریں، پھر خالی قطار سے ورک شیٹ شروع کریں۔',
    hi: 'अभी कोई पंक्तियाँ नहीं हैं। कॉलम जोड़ें, फिर खाली पंक्ति से वर्कशीट शुरू करें।',
  );
  static const noColumns = TranslatableString(
    en: 'No columns yet. Add a column before entering a row.',
    ar: 'لا توجد أعمدة بعد. أضف عموداً قبل إدخال صف.',
    ur: 'ابھی کوئی کالم نہیں۔ قطار درج کرنے سے پہلے کالم شامل کریں۔',
    hi: 'अभी कोई कॉलम नहीं हैं। पंक्ति दर्ज करने से पहले एक कॉलम जोड़ें।',
  );
  static const add = TranslatableString(
    en: 'Add',
    ar: 'إضافة',
    ur: 'شامل کریں',
    hi: 'जोड़ें',
  );
  static const cancel = TranslatableString(
    en: 'Cancel',
    ar: 'إلغاء',
    ur: 'منسوخ کریں',
    hi: 'रद्द करें',
  );
  static const archiveGroupConfirmation = TranslatableString(
    en: 'Archive this custom group? Its worksheet stays available in the audit history.',
    ar: 'أرشفة هذه المجموعة المخصصة؟ تبقى ورقة عملها متاحة في سجل التدقيق.',
    ur: 'کیا اس کسٹم گروپ کو آرکائیو کریں؟ اس کی ورک شیٹ آڈٹ ہسٹری میں دستیاب رہے گی۔',
    hi: 'क्या इस कस्टम समूह को आर्काइव करें? इसकी वर्कशीट ऑडिट इतिहास में उपलब्ध रहेगी।',
  );
  static const saveFailed = TranslatableString(
    en: 'Could not save this worksheet. Check the highlighted details and try again.',
    ar: 'تعذر حفظ ورقة العمل. تحقق من التفاصيل المميزة وحاول مرة أخرى.',
    ur: 'ورک شیٹ محفوظ نہیں ہو سکی۔ نمایاں تفصیلات چیک کریں اور دوبارہ کوشش کریں۔',
    hi: 'वर्कशीट सहेजी नहीं जा सकी। हाइलाइट किए गए विवरण जाँचें और फिर प्रयास करें।',
  );
  static const description = TranslatableString(
    en: 'Item description',
    ar: 'وصف الصنف',
    ur: 'آئٹم کی تفصیل',
    hi: 'आइटम विवरण',
  );
  static const size = TranslatableString(
    en: 'Size / dimension',
    ar: 'المقاس / الأبعاد',
    ur: 'سائز / ڈائمینشن',
    hi: 'आकार / आयाम',
  );
  static const model = TranslatableString(
    en: 'Model',
    ar: 'الطراز',
    ur: 'ماڈل',
    hi: 'मॉडल',
  );
  static const equipmentTag = TranslatableString(
    en: 'Equipment tag',
    ar: 'وسم المعدة',
    ur: 'آلاتی ٹیگ',
    hi: 'उपकरण टैग',
  );
  static const brandOrigin = TranslatableString(
    en: 'Brand / origin',
    ar: 'العلامة التجارية / المنشأ',
    ur: 'برانڈ / اصل',
    hi: 'ब्रांड / मूल',
  );
  static const quantity = TranslatableString(
    en: 'Quantity',
    ar: 'الكمية',
    ur: 'مقدار',
    hi: 'मात्रा',
  );
  static const unit = TranslatableString(
    en: 'Unit',
    ar: 'الوحدة',
    ur: 'یونٹ',
    hi: 'इकाई',
  );
  static const planningModelTag = TranslatableString(
    en: 'Planning model / tag',
    ar: 'نموذج / علامة التخطيط',
    ur: 'پلاننگ ماڈل / ٹیگ',
    hi: 'प्लानिंग मॉडल / टैग',
  );
  static const importWorkbook = TranslatableString(
    en: 'Import Excel',
    ar: 'استيراد Excel',
    ur: 'Excel امپورٹ کریں',
    hi: 'Excel आयात करें',
  );
  static const exportWorkbook = TranslatableString(
    en: 'Export Excel',
    ar: 'تصدير مصنف',
    ur: 'ورک بک ایکسپورٹ کریں',
    hi: 'वर्कबुक निर्यात करें',
  );
  static const chooseWorkbook = TranslatableString(
    en: 'Choose XLSX file',
    ar: 'اختر ملف XLSX',
    ur: 'XLSX فائل منتخب کریں',
    hi: 'XLSX फ़ाइल चुनें',
  );
  static const importPreview = TranslatableString(
    en: 'Import preview',
    ar: 'معاينة الاستيراد',
    ur: 'امپورٹ پری ویو',
    hi: 'आयात पूर्वावलोकन',
  );
  static const worksheetSelection = TranslatableString(
    en: 'Worksheet',
    ar: 'ورقة العمل',
    ur: 'ورک شیٹ',
    hi: 'वर्कशीट',
  );
  static const headerRow = TranslatableString(
    en: 'Header row',
    ar: 'صف العنوان',
    ur: 'ہیڈر قطار',
    hi: 'हेडर पंक्ति',
  );
  static const detectedTitle = TranslatableString(
    en: 'Worksheet title',
    ar: 'عنوان ورقة العمل',
    ur: 'ورک شیٹ کا عنوان',
    hi: 'वर्कशीट शीर्षक',
  );
  static const columnMapping = TranslatableString(
    en: 'Column mapping',
    ar: 'تعيين الأعمدة',
    ur: 'کالم میپنگ',
    hi: 'कॉलम मैपिंग',
  );
  static const noCanonicalMapping = TranslatableString(
    en: 'Keep as worksheet-only column',
    ar: 'الاحتفاظ به كعمود لورقة العمل فقط',
    ur: 'صرف ورک شیٹ کالم کے طور پر رکھیں',
    hi: 'केवल वर्कशीट कॉलम के रूप में रखें',
  );
  static const previewRows = TranslatableString(
    en: 'Preview rows',
    ar: 'معاينة الصفوف',
    ur: 'پری ویو قطاریں',
    hi: 'पूर्वावलोकन पंक्तियाँ',
  );
  static const commitImport = TranslatableString(
    en: 'Import into this worksheet',
    ar: 'استيراد إلى ورقة العمل هذه',
    ur: 'اس ورک شیٹ میں امپورٹ کریں',
    hi: 'इस वर्कशीट में आयात करें',
  );
  static const importDescription = TranslatableString(
    en: 'Review the detected title, header row and mappings before replacing this worksheet. Importing never submits a Material Request.',
    ar: 'راجع العنوان وصف العناوين والتعيينات قبل استبدال ورقة العمل هذه. الاستيراد لا يرسل طلب مواد أبداً.',
    ur: 'اس ورک شیٹ کو تبدیل کرنے سے پہلے شناخت شدہ عنوان، ہیڈر قطار اور میپنگز دیکھیں۔ امپورٹ کبھی میٹریل ریکوئسٹ جمع نہیں کرتا۔',
    hi: 'इस वर्कशीट को बदलने से पहले पहचाने गए शीर्षक, हेडर पंक्ति और मैपिंग की समीक्षा करें। आयात कभी सामग्री अनुरोध जमा नहीं करता।',
  );
  static const imported = TranslatableString(
    en: 'Workbook imported.',
    ar: 'تم استيراد المصنف.',
    ur: 'ورک بک امپورٹ ہو گئی۔',
    hi: 'वर्कबुक आयात हो गई।',
  );
  static const exported = TranslatableString(
    en: 'Workbook export is ready.',
    ar: 'تصدير المصنف جاهز.',
    ur: 'ورک بک ایکسپورٹ تیار ہے۔',
    hi: 'वर्कबुक निर्यात तैयार है।',
  );
  static const importFailed = TranslatableString(
    en: 'Could not import this workbook. Check the file and preview details, then try again.',
    ar: 'تعذر استيراد هذا المصنف. تحقق من الملف وتفاصيل المعاينة ثم حاول مرة أخرى.',
    ur: 'یہ ورک بک امپورٹ نہیں ہو سکی۔ فائل اور پری ویو تفصیلات دیکھیں، پھر دوبارہ کوشش کریں۔',
    hi: 'यह कार्यपुस्तिका आयात नहीं हो सकी। फ़ाइल और पूर्वावलोकन विवरण जाँचें, फिर प्रयास करें।',
  );
  static const exportFailed = TranslatableString(
    en: 'Could not export this worksheet.',
    ar: 'تعذر تصدير ورقة العمل هذه.',
    ur: 'یہ ورک شیٹ ایکسپورٹ نہیں ہو سکی۔',
    hi: 'यह वर्कशीट निर्यात नहीं हो सकी।',
  );
  static const importNoColumns = TranslatableString(
    en: 'Choose a header row that contains at least one column heading.',
    ar: 'اختر صف عنوان يحتوي على عنوان عمود واحد على الأقل.',
    ur: 'ایسی ہیڈر قطار منتخب کریں جس میں کم از کم ایک کالم ہیڈنگ ہو۔',
    hi: 'ऐसी हेडर पंक्ति चुनें जिसमें कम से कम एक कॉलम शीर्षक हो।',
  );
  static const importBlankHeading = TranslatableString(
    en: 'Give every imported column a heading before continuing.',
    ar: 'أعطِ كل عمود مستورد عنواناً قبل المتابعة.',
    ur: 'جاری رکھنے سے پہلے ہر امپورٹ شدہ کالم کو ہیڈنگ دیں۔',
    hi: 'आगे बढ़ने से पहले हर आयातित कॉलम को शीर्षक दें।',
  );
  static const importDuplicateHeading = TranslatableString(
    en: 'Imported column headings must be unique.',
    ar: 'يجب أن تكون عناوين الأعمدة المستوردة فريدة.',
    ur: 'امپورٹ شدہ کالم ہیڈنگز منفرد ہونی چاہئیں۔',
    hi: 'आयातित कॉलम शीर्षक अद्वितीय होने चाहिए।',
  );
  static const importDuplicateCanonical = TranslatableString(
    en: 'Use each searchable mapping only once.',
    ar: 'استخدم كل تعيين قابل للبحث مرة واحدة فقط.',
    ur: 'ہر قابل تلاش میپنگ صرف ایک بار استعمال کریں۔',
    hi: 'प्रत्येक खोज योग्य मैपिंग केवल एक बार उपयोग करें।',
  );
}
