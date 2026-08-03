import 'app_strings.dart';
import 'yorks_v1_material_request.dart';

/// Centralized bilingual-capable presentation copy for the Yorks V1 Material
/// Request slice. Domain and database layers use stable codes, never this copy.
abstract final class YorksV1MaterialRequestStrings {
  static const companyName = TranslatableString(
    en: 'Yorks AC. & Ref.',
    ar: 'يوركس للتكييف والتبريد',
    ur: 'یارکس اے سی اینڈ ریف',
    hi: 'यॉर्क्स एसी एंड रेफ.',
  );
  static const companyLegalName = TranslatableString(
    en: 'Yorks Air Conditioning and Refrigeration LLC-SPC',
    ar: 'يوركس للتكييف والتبريد ذ.م.م - ش.ش.و',
    ur: 'یارکس ایئر کنڈیشننگ اینڈ ریفریجریشن ایل ایل سی-ایس پی سی',
    hi: 'यॉर्क्स एयर कंडीशनिंग एंड रेफ्रिजरेशन LLC-SPC',
  );
  static const materialRequest = TranslatableString(
    en: 'Material Request',
    ar: 'طلب مواد',
    ur: 'مواد کی درخواست',
    hi: 'सामग्री अनुरोध',
  );
  static const materialRequestDraft = TranslatableString(
    en: 'Material Request Draft',
    ar: 'مسودة طلب مواد',
    ur: 'مواد کی درخواست کا مسودہ',
    hi: 'सामग्री अनुरोध ड्राफ़्ट',
  );
  static const requests = TranslatableString(
    en: 'Material Requests',
    ar: 'طلبات المواد',
    ur: 'مواد کی درخواستیں',
    hi: 'सामग्री अनुरोध',
  );
  static const requestsDescription = TranslatableString(
    en: 'The Engineer and Procurement see the same request number, item order and status.',
    ar: 'يرى المهندس والمشتريات رقم الطلب وترتيب البنود والحالة نفسها.',
    ur: 'انجینئر اور پروکیورمنٹ ایک ہی درخواست نمبر، آئٹم ترتیب اور حالت دیکھتے ہیں۔',
    hi: 'इंजीनियर और खरीद विभाग को वही अनुरोध संख्या, आइटम क्रम और स्थिति दिखाई देती है।',
  );
  static const workflowDescription = TranslatableString(
    en: 'Submitted → Procurement arrangement → Project Engineer approval → Dispatch → Site receipt → Return, when required.',
    ar: 'إرسال ← ترتيب المشتريات ← موافقة مهندس المشروع ← الإرسال ← استلام الموقع ← الإرجاع عند الحاجة.',
    ur: 'جمع کرائی گئی → پروکیورمنٹ انتظام → پروجیکٹ انجینئر منظوری → ڈسپیچ → سائٹ وصولی → ضرورت پر واپسی۔',
    hi: 'जमा किया गया → खरीद व्यवस्था → प्रोजेक्ट इंजीनियर अनुमोदन → डिस्पैच → साइट प्राप्ति → आवश्यक होने पर वापसी।',
  );
  static const workflowTitle = TranslatableString(
    en: 'One Material Request carries the complete workflow.',
    ar: 'طلب مواد واحد يحمل سير العمل الكامل.',
    ur: 'ایک مواد کی درخواست مکمل ورک فلو رکھتی ہے۔',
    hi: 'एक सामग्री अनुरोध पूरा वर्कफ़्लो रखता है।',
  );
  static const refresh = TranslatableString(
    en: 'Refresh',
    ar: 'تحديث',
    ur: 'ریفریش',
    hi: 'रीफ़्रेश',
  );
  static const cancel = TranslatableString(
    en: 'Cancel',
    ar: 'إلغاء',
    ur: 'منسوخ کریں',
    hi: 'रद्द करें',
  );
  static const rowNumber = TranslatableString(
    en: 'R No',
    ar: 'رقم البند',
    ur: 'قطار نمبر',
    hi: 'पंक्ति सं.',
  );
  static const serialNumber = TranslatableString(
    en: 'S:NO',
    ar: 'رقم',
    ur: 'نمبر',
    hi: 'क्र.',
  );
  static const newRequest = TranslatableString(
    en: 'New Material Request',
    ar: 'طلب مواد جديدة',
    ur: 'نئی مواد کی درخواست',
    hi: 'नया सामग्री अनुरोध',
  );
  static const editDraft = TranslatableString(
    en: 'Edit material request draft',
    ar: 'تحرير مسودة طلب المواد',
    ur: 'مواد کی درخواست کا مسودہ ترمیم کریں',
    hi: 'सामग्री अनुरोध ड्राफ़्ट संपादित करें',
  );
  static const draftPrivate = TranslatableString(
    en: 'Draft — visible only to you',
    ar: 'مسودة — مرئية لك فقط',
    ur: 'مسودہ — صرف آپ کو نظر آتا ہے',
    hi: 'ड्राफ़्ट — केवल आपको दिखाई देता है',
  );
  static const draft = TranslatableString(
    en: 'Draft',
    ar: 'مسودة',
    ur: 'مسودہ',
    hi: 'ड्राफ़्ट',
  );
  static const arranging = TranslatableString(
    en: 'Arranging',
    ar: 'قيد الترتيب',
    ur: 'انتظام جاری ہے',
    hi: 'व्यवस्था जारी है',
  );
  static const awaitingApproval = TranslatableString(
    en: 'Awaiting approval',
    ar: 'بانتظار الموافقة',
    ur: 'منظوری کا انتظار',
    hi: 'अनुमोदन की प्रतीक्षा',
  );
  static const approved = TranslatableString(
    en: 'Approved',
    ar: 'معتمد',
    ur: 'منظور شدہ',
    hi: 'स्वीकृत',
  );
  static const partiallyDispatched = TranslatableString(
    en: 'Partially dispatched',
    ar: 'تم الإرسال جزئيًا',
    ur: 'جزوی طور پر بھیجا گیا',
    hi: 'आंशिक रूप से भेजा गया',
  );
  static const dispatched = TranslatableString(
    en: 'Dispatched',
    ar: 'تم الإرسال',
    ur: 'بھیج دیا گیا',
    hi: 'भेज दिया गया',
  );
  static const partiallyReceived = TranslatableString(
    en: 'Partially received',
    ar: 'تم الاستلام جزئيًا',
    ur: 'جزوی وصول شدہ',
    hi: 'आंशिक रूप से प्राप्त',
  );
  static const received = TranslatableString(
    en: 'Received',
    ar: 'تم الاستلام',
    ur: 'وصول شدہ',
    hi: 'प्राप्त',
  );
  static const closed = TranslatableString(
    en: 'Closed',
    ar: 'مغلق',
    ur: 'بند',
    hi: 'बंद',
  );
  static const requestTitle = TranslatableString(
    en: 'Request Title optional',
    ar: 'عنوان الطلب (اختياري)',
    ur: 'درخواست کا عنوان (اختیاری)',
    hi: 'अनुरोध शीर्षक (वैकल्पिक)',
  );
  static const requestInformation = TranslatableString(
    en: 'Request Information',
    ar: 'معلومات الطلب',
    ur: 'درخواست کی معلومات',
    hi: 'अनुरोध जानकारी',
  );
  static const requestInformationDescription = TranslatableString(
    en: 'This information is shown to Procurement and printed on the Material Request.',
    ar: 'تظهر هذه المعلومات للمشتريات وتُطبع في طلب المواد.',
    ur: 'یہ معلومات پروکیورمنٹ کو دکھائی جاتی ہیں اور مواد کی درخواست پر پرنٹ ہوتی ہیں۔',
    hi: 'यह जानकारी खरीद विभाग को दिखाई जाती है और सामग्री अनुरोध पर मुद्रित होती है।',
  );
  static const requestScopeDescription = TranslatableString(
    en: 'Choose one building or Common / All Buildings. Add custom items, choose items from BOQ folders, or import an Excel file.',
    ar: 'اختر مبنى واحدًا أو المشترك / جميع المباني. أضف عناصر مخصصة أو اختر عناصر من مجلدات جدول الكميات أو استورد ملف Excel.',
    ur: 'ایک عمارت یا مشترکہ / تمام عمارتیں منتخب کریں۔ کسٹم آئٹمز شامل کریں، BOQ فولڈرز سے آئٹمز منتخب کریں، یا Excel فائل درآمد کریں۔',
    hi: 'एक भवन या सामान्य / सभी भवन चुनें। कस्टम आइटम जोड़ें, बीओक्यू फ़ोल्डर से आइटम चुनें या Excel फ़ाइल आयात करें।',
  );
  static const materialItems = TranslatableString(
    en: 'Material Items',
    ar: 'مواد الطلب',
    ur: 'میٹیریل آئٹمز',
    hi: 'सामग्री आइटम',
  );
  static const materialItemsDescription = TranslatableString(
    en: 'Remarks are removed. The item order matches the familiar Yorks Material Request form.',
    ar: 'تمت إزالة الملاحظات. يطابق ترتيب البنود نموذج طلب مواد Yorks المعتاد.',
    ur: 'ریمارکس ہٹا دیے گئے ہیں۔ آئٹم کی ترتیب Yorks کے مانوس مواد درخواست فارم کے مطابق ہے۔',
    hi: 'टिप्पणियाँ हटा दी गई हैं। आइटम क्रम परिचित Yorks सामग्री अनुरोध फॉर्म से मेल खाता है।',
  );
  static const addItems = TranslatableString(
    en: 'Add items',
    ar: 'إضافة بنود',
    ur: 'آئٹمز شامل کریں',
    hi: 'आइटम जोड़ें',
  );
  static const ready = TranslatableString(
    en: 'Ready',
    ar: 'جاهز',
    ur: 'تیار',
    hi: 'तैयार',
  );
  static const reviewDescription = TranslatableString(
    en: 'The request number is generated from Project Reference + MR number.',
    ar: 'يتم إنشاء رقم الطلب من مرجع المشروع + رقم طلب المواد.',
    ur: 'درخواست نمبر پروجیکٹ ریفرنس + MR نمبر سے تیار ہوتا ہے۔',
    hi: 'अनुरोध संख्या प्रोजेक्ट संदर्भ + MR संख्या से बनती है।',
  );
  static const review = TranslatableString(
    en: 'Review',
    ar: 'مراجعة',
    ur: 'جائزہ',
    hi: 'समीक्षा',
  );
  static const project = TranslatableString(
    en: 'Project',
    ar: 'المشروع',
    ur: 'پروجیکٹ',
    hi: 'परियोजना',
  );
  static const scope = TranslatableString(
    en: 'Building / Common scope',
    ar: 'نطاق المبنى / المشترك',
    ur: 'عمارت / مشترکہ دائرہ',
    hi: 'भवन / सामान्य दायरा',
  );
  static const scopeLabel = TranslatableString(
    en: 'Scope',
    ar: 'النطاق',
    ur: 'دائرہ',
    hi: 'दायरा',
  );
  static const delivery = TranslatableString(
    en: 'Delivery',
    ar: 'التسليم',
    ur: 'ترسیل',
    hi: 'डिलीवरी',
  );
  static const timing = TranslatableString(
    en: 'Timing',
    ar: 'التوقيت',
    ur: 'وقت',
    hi: 'समय',
  );
  static const requestTiming = TranslatableString(
    en: 'Request Timing',
    ar: 'توقيت الطلب',
    ur: 'درخواست کا وقت',
    hi: 'अनुरोध समय',
  );
  static const buildingOther = TranslatableString(
    en: 'Building / Other',
    ar: 'المبنى / أخرى',
    ur: 'عمارت / دیگر',
    hi: 'भवन / अन्य',
  );
  static const state = TranslatableString(
    en: 'State',
    ar: 'الحالة',
    ur: 'حالت',
    hi: 'स्थिति',
  );
  static const urgent = TranslatableString(
    en: 'Urgent',
    ar: 'عاجل',
    ur: 'فوری',
    hi: 'तत्काल',
  );
  static const normal = TranslatableString(
    en: 'Normal',
    ar: 'عادي',
    ur: 'معمول',
    hi: 'सामान्य',
  );
  static const scheduled = TranslatableString(
    en: 'Scheduled',
    ar: 'مجدول',
    ur: 'شیڈول شدہ',
    hi: 'निर्धारित',
  );
  static const scheduledDate = TranslatableString(
    en: 'Scheduled date',
    ar: 'التاريخ المجدول',
    ur: 'شیڈول کی تاریخ',
    hi: 'निर्धारित तिथि',
  );
  static const deliveryNote = TranslatableString(
    en: 'Delivery note (optional)',
    ar: 'ملاحظة التسليم (اختيارية)',
    ur: 'ترسیل نوٹ (اختیاری)',
    hi: 'डिलीवरी नोट (वैकल्पिक)',
  );
  static const deliveryNoteLabel = TranslatableString(
    en: 'Delivery note',
    ar: 'ملاحظة التسليم',
    ur: 'ترسیل نوٹ',
    hi: 'डिलीवरी नोट',
  );
  static const lines = TranslatableString(
    en: 'Request lines',
    ar: 'بنود الطلب',
    ur: 'درخواست کی سطور',
    hi: 'अनुरोध पंक्तियाँ',
  );
  static const addCustomLine = TranslatableString(
    en: 'Add custom line',
    ar: 'إضافة بند مخصص',
    ur: 'کسٹم سطر شامل کریں',
    hi: 'कस्टम पंक्ति जोड़ें',
  );
  static const addCustomItem = TranslatableString(
    en: 'Add Custom Item',
    ar: 'إضافة عنصر مخصص',
    ur: 'کسٹم آئٹم شامل کریں',
    hi: 'कस्टम आइटम जोड़ें',
  );
  static const addBlankRow = TranslatableString(
    en: 'Add Blank Row',
    ar: 'إضافة صف فارغ',
    ur: 'خالی قطار شامل کریں',
    hi: 'खाली पंक्ति जोड़ें',
  );
  static const addSimilarRow = TranslatableString(
    en: 'Add Similar Row',
    ar: 'إضافة صف مماثل',
    ur: 'ملتا جلتا قطار شامل کریں',
    hi: 'समान पंक्ति जोड़ें',
  );
  static const addFromBoq = TranslatableString(
    en: 'Add from BOQ',
    ar: 'إضافة من جدول الكميات',
    ur: 'BOQ سے شامل کریں',
    hi: 'बीओक्यू से जोड़ें',
  );
  static const useEntireBoqFolder = TranslatableString(
    en: 'Use entire BOQ folder',
    ar: 'استخدم مجلد جدول الكميات بالكامل',
    ur: 'پورا BOQ فولڈر استعمال کریں',
    hi: 'पूरा BOQ फ़ोल्डर उपयोग करें',
  );
  static const importExcel = TranslatableString(
    en: 'Import Excel',
    ar: 'استيراد ملف Excel مضبوط',
    ur: 'کنٹرول شدہ Excel درآمد کریں',
    hi: 'नियंत्रित Excel आयात करें',
  );
  static const chooseEquipmentSchedule = TranslatableString(
    en: 'Choose Equipment Schedule',
    ar: 'اختر جدول المعدات',
    ur: 'Equipment Schedule منتخب کریں',
    hi: 'उपकरण शेड्यूल चुनें',
  );
  static const worksheetImportDescription = TranslatableString(
    en: 'Select the worksheet to import into this material list.',
    ar: 'حدد ورقة العمل لاستيرادها إلى قائمة المواد هذه.',
    ur: 'اس میٹیریل فہرست میں درآمد کرنے کے لیے ورک شیٹ منتخب کریں۔',
    hi: 'इस सामग्री सूची में आयात करने के लिए वर्कशीट चुनें।',
  );
  static const previewImport = TranslatableString(
    en: 'Preview import',
    ar: 'معاينة الاستيراد',
    ur: 'درآمد کا پیش نظارہ',
    hi: 'आयात का पूर्वावलोकन',
  );
  static const addImportedRows = TranslatableString(
    en: 'Add rows to draft',
    ar: 'إضافة الصفوف إلى المسودة',
    ur: 'قطار مسودے میں شامل کریں',
    hi: 'ड्राफ़्ट में पंक्तियाँ जोड़ें',
  );
  static const rows = TranslatableString(
    en: 'rows',
    ar: 'صفوف',
    ur: 'قطار',
    hi: 'पंक्तियाँ',
  );
  static const importPreviewLimit = TranslatableString(
    en: 'Preview shows the first 25 rows; all rows will be added.',
    ar: 'تُظهر المعاينة أول 25 صفًا؛ ستتم إضافة جميع الصفوف.',
    ur: 'پیش نظارہ پہلی 25 قطاریں دکھاتا ہے؛ تمام قطاریں شامل کی جائیں گی۔',
    hi: 'पूर्वावलोकन पहली 25 पंक्तियाँ दिखाता है; सभी पंक्तियाँ जोड़ दी जाएँगी।',
  );
  static const importCostMismatch = TranslatableString(
    en: 'Some imported totals do not match Qty × Unit Cost. Totals will be recalculated when the controlled document is generated.',
    ar: 'بعض الإجماليات المستوردة لا تطابق الكمية × تكلفة الوحدة. ستتم إعادة حساب الإجماليات عند إنشاء المستند المضبوط.',
    ur: 'کچھ درآمد شدہ ٹوٹل مقدار × فی یونٹ لاگت سے مطابقت نہیں رکھتے۔ کنٹرول شدہ دستاویز بناتے وقت ٹوٹل دوبارہ حساب ہوگا۔',
    hi: 'कुछ आयातित कुल Qty × Unit Cost से मेल नहीं खाते। नियंत्रित दस्तावेज़ बनाते समय कुल की पुनर्गणना होगी।',
  );
  static const cancelImport = TranslatableString(
    en: 'Cancel import',
    ar: 'إلغاء الاستيراد',
    ur: 'درآمد منسوخ کریں',
    hi: 'आयात रद्द करें',
  );
  static const itemDescription = TranslatableString(
    en: 'Item Description',
    ar: 'وصف الصنف',
    ur: 'آئٹم کی تفصیل',
    hi: 'आइटम विवरण',
  );
  static const brandOrigin = TranslatableString(
    en: 'Brand/Origin',
    ar: 'العلامة/المنشأ',
    ur: 'برانڈ/اصل',
    hi: 'ब्रांड/मूल',
  );
  static const size = TranslatableString(
    en: 'Size (if any)',
    ar: 'المقاس (إن وجد)',
    ur: 'سائز (اگر ہو)',
    hi: 'आकार (यदि कोई हो)',
  );
  static const planningModelTag = TranslatableString(
    en: 'Model / Tag',
    ar: 'النموذج / الوسم',
    ur: 'ماڈل / ٹیگ',
    hi: 'मॉडल / टैग',
  );
  static const modelSerialNumber = TranslatableString(
    en: 'Model / Serial No.',
    ar: 'رقم الطراز / الرقم التسلسلي',
    ur: 'ماڈل / سیریل نمبر',
    hi: 'मॉडल / सीरियल नं.',
  );
  static const quantity = TranslatableString(
    en: 'Qty',
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
  static const unitCost = TranslatableString(
    en: 'Unit Cost',
    ar: 'تكلفة الوحدة',
    ur: 'فی یونٹ لاگت',
    hi: 'इकाई लागत',
  );
  static const totalCost = TranslatableString(
    en: 'Total Cost',
    ar: 'التكلفة الإجمالية',
    ur: 'کل لاگت',
    hi: 'कुल लागत',
  );
  static const saveDraft = TranslatableString(
    en: 'Save draft',
    ar: 'حفظ المسودة',
    ur: 'مسودہ محفوظ کریں',
    hi: 'ड्राफ़्ट सहेजें',
  );
  static const submitToProcurement = TranslatableString(
    en: 'Submit to Procurement',
    ar: 'إرسال إلى المشتريات',
    ur: 'پروکیورمنٹ کو جمع کرائیں',
    hi: 'खरीद विभाग को भेजें',
  );
  static const submitted = TranslatableString(
    en: 'Submitted to Procurement',
    ar: 'تم الإرسال إلى المشتريات',
    ur: 'پروکیورمنٹ کو جمع کرایا گیا',
    hi: 'खरीद विभाग को भेजा गया',
  );
  static const saved = TranslatableString(
    en: 'Draft saved',
    ar: 'تم حفظ المسودة',
    ur: 'مسودہ محفوظ ہو گیا',
    hi: 'ड्राफ़्ट सहेजा गया',
  );
  static const savedLocally = TranslatableString(
    en: 'Draft saved on this device. Complete the request to sync it.',
    ar: 'تم حفظ المسودة على هذا الجهاز. أكمل الطلب لمزامنته.',
    ur: 'مسودہ اس ڈیوائس پر محفوظ ہو گیا۔ اسے ہم وقت کرنے کے لیے درخواست مکمل کریں۔',
    hi: 'ड्राफ़्ट इस डिवाइस पर सहेजा गया। सिंक करने के लिए अनुरोध पूरा करें।',
  );
  static const saveFailed = TranslatableString(
    en: 'Could not save this draft.',
    ar: 'تعذر حفظ هذه المسودة.',
    ur: 'یہ مسودہ محفوظ نہیں ہو سکا۔',
    hi: 'यह ड्राफ़्ट सहेजा नहीं जा सका।',
  );
  static const submitFailed = TranslatableString(
    en: 'Could not submit this material request.',
    ar: 'تعذر إرسال طلب المواد هذا.',
    ur: 'یہ مواد کی درخواست جمع نہیں ہو سکی۔',
    hi: 'यह सामग्री अनुरोध भेजा नहीं जा सका।',
  );
  static const offlineSubmit = TranslatableString(
    en: 'Connect to submit this request. Your draft remains safely on this device.',
    ar: 'اتصل بالإنترنت لإرسال هذا الطلب. ستبقى مسودتك محفوظة على هذا الجهاز.',
    ur: 'اس درخواست کو جمع کرانے کے لیے انٹرنیٹ سے جڑیں۔ آپ کا مسودہ اس ڈیوائس پر محفوظ رہے گا۔',
    hi: 'इस अनुरोध को भेजने के लिए कनेक्ट करें। आपका ड्राफ़्ट इस डिवाइस पर सुरक्षित रहेगा।',
  );
  static const missingRequired = TranslatableString(
    en: 'Choose a project and scope, complete valid lines, and add a scheduled date when needed.',
    ar: 'اختر مشروعًا ونطاقًا، وأكمل البنود الصالحة، وأضف تاريخًا مجدولًا عند الحاجة.',
    ur: 'پروجیکٹ اور دائرہ منتخب کریں، درست سطور مکمل کریں، اور ضرورت ہو تو شیڈول کی تاریخ شامل کریں۔',
    hi: 'परियोजना और दायरा चुनें, मान्य पंक्तियाँ पूरी करें और जरूरत होने पर निर्धारित तिथि जोड़ें।',
  );
  static const projectMustBeActive = TranslatableString(
    en: 'Activate the selected project before submitting this request.',
    ar: 'فعّل المشروع المحدد قبل إرسال هذا الطلب.',
    ur: 'اس درخواست کو جمع کرانے سے پہلے منتخب پراجیکٹ فعال کریں۔',
    hi: 'इस अनुरोध को भेजने से पहले चुनी हुई परियोजना सक्रिय करें।',
  );
  static const noRequests = TranslatableString(
    en: 'No material requests are available yet.',
    ar: 'لا توجد طلبات مواد متاحة بعد.',
    ur: 'ابھی کوئی مواد کی درخواست دستیاب نہیں ہے۔',
    hi: 'अभी कोई सामग्री अनुरोध उपलब्ध नहीं है।',
  );
  static const requestNumber = TranslatableString(
    en: 'Request number',
    ar: 'رقم الطلب',
    ur: 'درخواست نمبر',
    hi: 'अनुरोध संख्या',
  );
  static const currentOwner = TranslatableString(
    en: 'Current owner',
    ar: 'المالك الحالي',
    ur: 'موجودہ ذمہ دار',
    hi: 'वर्तमान स्वामी',
  );
  static const nextAction = TranslatableString(
    en: 'Next action',
    ar: 'الإجراء التالي',
    ur: 'اگلا عمل',
    hi: 'अगली कार्रवाई',
  );
  static const requester = TranslatableString(
    en: 'Requester',
    ar: 'مقدم الطلب',
    ur: 'درخواست گزار',
    hi: 'अनुरोधकर्ता',
  );
  static const requestedBy = TranslatableString(
    en: 'Requested by',
    ar: 'مقدم الطلب',
    ur: 'درخواست گزار',
    hi: 'अनुरोधकर्ता',
  );
  static const notProvided = TranslatableString(
    en: '—',
    ar: '—',
    ur: '—',
    hi: '—',
  );
  static const projectEngineer = TranslatableString(
    en: 'Project Engineer',
    ar: 'مهندس المشروع',
    ur: 'پروجیکٹ انجینئر',
    hi: 'प्रोजेक्ट इंजीनियर',
  );
  static const items = TranslatableString(
    en: 'Items',
    ar: 'العناصر',
    ur: 'آئٹمز',
    hi: 'आइटम',
  );
  static const selectProject = TranslatableString(
    en: 'Select project',
    ar: 'اختر المشروع',
    ur: 'پروجیکٹ منتخب کریں',
    hi: 'परियोजना चुनें',
  );
  static const exportExcel = TranslatableString(
    en: 'Export Excel',
    ar: 'تصدير Excel',
    ur: 'Excel برآمد کریں',
    hi: 'Excel निर्यात करें',
  );
  static const printPdf = TranslatableString(
    en: 'Print / PDF',
    ar: 'طباعة / PDF',
    ur: 'پرنٹ / PDF',
    hi: 'प्रिंट / PDF',
  );
  static const cancelRequest = TranslatableString(
    en: 'Cancel request',
    ar: 'إلغاء الطلب',
    ur: 'درخواست منسوخ کریں',
    hi: 'अनुरोध रद्द करें',
  );
  static const cancelled = TranslatableString(
    en: 'Request cancelled',
    ar: 'تم إلغاء الطلب',
    ur: 'درخواست منسوخ ہو گئی',
    hi: 'अनुरोध रद्द किया गया',
  );
  static const cancelReason = TranslatableString(
    en: 'Cancellation reason',
    ar: 'سبب الإلغاء',
    ur: 'منسوخی کی وجہ',
    hi: 'रद्द करने का कारण',
  );
  static const importFailed = TranslatableString(
    en: 'The workbook needs Item Description, Qty and Unit columns.',
    ar: 'يحتاج المصنف إلى أعمدة وصف الصنف والكمية والوحدة.',
    ur: 'ورک بک میں آئٹم کی تفصیل، مقدار اور یونٹ کالم درکار ہیں۔',
    hi: 'वर्कबुक में आइटम विवरण, मात्रा और इकाई कॉलम चाहिए।',
  );
}

TranslatableString yorksV1MaterialRequestTimingCopy(
  YorksV1MaterialRequestTiming timing,
) => switch (timing) {
  YorksV1MaterialRequestTiming.urgent => YorksV1MaterialRequestStrings.urgent,
  YorksV1MaterialRequestTiming.normal => YorksV1MaterialRequestStrings.normal,
  YorksV1MaterialRequestTiming.scheduled =>
    YorksV1MaterialRequestStrings.scheduled,
};

TranslatableString yorksV1MaterialRequestStateCopy(
  YorksV1MaterialRequestState state,
) => switch (state) {
  YorksV1MaterialRequestState.draft => YorksV1MaterialRequestStrings.draft,
  YorksV1MaterialRequestState.submitted =>
    YorksV1MaterialRequestStrings.submitted,
  YorksV1MaterialRequestState.arranging =>
    YorksV1MaterialRequestStrings.arranging,
  YorksV1MaterialRequestState.awaitingApproval =>
    YorksV1MaterialRequestStrings.awaitingApproval,
  YorksV1MaterialRequestState.approved =>
    YorksV1MaterialRequestStrings.approved,
  YorksV1MaterialRequestState.partiallyDispatched =>
    YorksV1MaterialRequestStrings.partiallyDispatched,
  YorksV1MaterialRequestState.dispatched =>
    YorksV1MaterialRequestStrings.dispatched,
  YorksV1MaterialRequestState.partiallyReceived =>
    YorksV1MaterialRequestStrings.partiallyReceived,
  YorksV1MaterialRequestState.received =>
    YorksV1MaterialRequestStrings.received,
  YorksV1MaterialRequestState.closed => YorksV1MaterialRequestStrings.closed,
  YorksV1MaterialRequestState.cancelled =>
    YorksV1MaterialRequestStrings.cancelled,
};
