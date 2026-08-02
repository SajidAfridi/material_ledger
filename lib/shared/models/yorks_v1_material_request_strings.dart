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
  static const newRequest = TranslatableString(
    en: 'New material request',
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
    en: 'Request title (optional)',
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
  static const materialItems = TranslatableString(
    en: 'Material Items',
    ar: 'مواد الطلب',
    ur: 'میٹیریل آئٹمز',
    hi: 'सामग्री आइटम',
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
  static const timing = TranslatableString(
    en: 'Timing',
    ar: 'التوقيت',
    ur: 'وقت',
    hi: 'समय',
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
  static const addFromBoq = TranslatableString(
    en: 'Add from BOQ',
    ar: 'إضافة من جدول الكميات',
    ur: 'BOQ سے شامل کریں',
    hi: 'बीओक्यू से जोड़ें',
  );
  static const importExcel = TranslatableString(
    en: 'Import controlled Excel',
    ar: 'استيراد ملف Excel مضبوط',
    ur: 'کنٹرول شدہ Excel درآمد کریں',
    hi: 'नियंत्रित Excel आयात करें',
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
