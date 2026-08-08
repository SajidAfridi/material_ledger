import 'app_strings.dart';
import 'yorks_v1_arrangement.dart';

/// Centralized user-facing copy for the Batch 6 arrangement workflow.
abstract final class YorksV1ArrangementStrings {
  static const arrangement = TranslatableString(
    en: 'Procurement arrangement',
    ar: 'ترتيب المشتريات',
    ur: 'پروکیورمنٹ انتظام',
    hi: 'खरीद व्यवस्था',
  );
  static const arrangeMaterialRequest = TranslatableString(
    en: 'Arrange Material Request',
    ar: 'ترتيب طلب المواد',
    ur: 'مواد کی درخواست ترتیب دیں',
    hi: 'सामग्री अनुरोध व्यवस्थित करें',
  );
  static const arrangeMaterialRequestDescription = TranslatableString(
    en: 'Supply available lines or clearly mark what cannot be provided.',
    ar: 'وفّر البنود المتاحة أو وضّح بوضوح ما لا يمكن توفيره.',
    ur: 'دستیاب لائنیں فراہم کریں یا واضح طور پر نشان زد کریں جو فراہم نہیں ہو سکتیں۔',
    hi: 'उपलब्ध पंक्तियों की आपूर्ति करें या स्पष्ट रूप से चिह्नित करें कि क्या उपलब्ध नहीं कराया जा सकता।',
  );
  static const quantityRule = TranslatableString(
    en: 'Arranged quantity can never exceed the requested quantity. Warehouse quantities are also checked against current available inventory.',
    ar: 'لا يمكن أن تتجاوز الكمية المرتبة الكمية المطلوبة. كما يتم التحقق من كميات المستودع مقابل المخزون المتاح الحالي.',
    ur: 'ترتیب شدہ مقدار کبھی مطلوبہ مقدار سے زیادہ نہیں ہو سکتی۔ گودام کی مقدار بھی موجودہ دستیاب انوینٹری کے خلاف چیک ہوتی ہے۔',
    hi: 'व्यवस्थित मात्रा अनुरोधित मात्रा से अधिक नहीं हो सकती। गोदाम की मात्राओं की वर्तमान उपलब्ध इन्वेंटरी से भी जांच होती है।',
  );
  static const arrangementHistory = TranslatableString(
    en: 'Arrangement history',
    ar: 'سجل الترتيبات',
    ur: 'انتظام کی تاریخ',
    hi: 'व्यवस्था इतिहास',
  );
  static const startArrangement = TranslatableString(
    en: 'Start arrangement',
    ar: 'بدء الترتيب',
    ur: 'انتظام شروع کریں',
    hi: 'व्यवस्था शुरू करें',
  );
  static const saveForApproval = TranslatableString(
    en: 'Send to Project Engineer',
    ar: 'إرسال لموافقة مهندس المشروع',
    ur: 'پروجیکٹ انجینئر کی منظوری کے لیے بھیجیں',
    hi: 'प्रोजेक्ट इंजीनियर की मंजूरी के लिए भेजें',
  );
  static const approveArrangement = TranslatableString(
    en: 'Approve arrangement',
    ar: 'اعتماد الترتيب',
    ur: 'انتظام منظور کریں',
    hi: 'व्यवस्था स्वीकृत करें',
  );
  static const reviewAndApprove = TranslatableString(
    en: 'Review & Approve',
    ar: 'مراجعة واعتماد',
    ur: 'جائزہ لیں اور منظور کریں',
    hi: 'समीक्षा करें और स्वीकृत करें',
  );
  static const returnToProcurement = TranslatableString(
    en: 'Return to Procurement',
    ar: 'إعادة إلى المشتريات',
    ur: 'پروکیورمنٹ کو واپس بھیجیں',
    hi: 'खरीद विभाग को लौटाएँ',
  );
  static const returnReason = TranslatableString(
    en: 'Return reason',
    ar: 'سبب الإرجاع',
    ur: 'واپسی کی وجہ',
    hi: 'वापसी का कारण',
  );
  static const requested = TranslatableString(
    en: 'Requested',
    ar: 'المطلوب',
    ur: 'درخواست کردہ',
    hi: 'अनुरोधित',
  );
  static const requestedItem = TranslatableString(
    en: 'Requested item',
    ar: 'البند المطلوب',
    ur: 'درخواست کردہ آئٹم',
    hi: 'अनुरोधित आइटम',
  );
  static const supplierSource = TranslatableString(
    en: 'Supplier / source',
    ar: 'المورد / المصدر',
    ur: 'سپلائر / ذریعہ',
    hi: 'आपूर्तिकर्ता / स्रोत',
  );
  static const rowNumber = TranslatableString(
    en: 'R No',
    ar: 'رقم البند',
    ur: 'قطار نمبر',
    hi: 'पंक्ति सं.',
  );
  static const arranged = TranslatableString(
    en: 'Arranged',
    ar: 'الكمية المرتبة',
    ur: 'انتظام شدہ',
    hi: 'व्यवस्थित',
  );
  static const decision = TranslatableString(
    en: 'Decision',
    ar: 'القرار',
    ur: 'فیصلہ',
    hi: 'निर्णय',
  );
  static const source = TranslatableString(
    en: 'Source',
    ar: 'المصدر',
    ur: 'ماخذ',
    hi: 'स्रोत',
  );
  static const warehouse = TranslatableString(
    en: 'Warehouse',
    ar: 'المستودع',
    ur: 'گودام',
    hi: 'वेयरहाउस',
  );
  static const externalSupplier = TranslatableString(
    en: 'External supplier',
    ar: 'مورد خارجي',
    ur: 'بیرونی سپلائر',
    hi: 'बाहरी आपूर्तिकर्ता',
  );
  static const supplierName = TranslatableString(
    en: 'Supplier name',
    ar: 'اسم المورد',
    ur: 'سپلائر کا نام',
    hi: 'आपूर्तिकर्ता का नाम',
  );
  static const warehouseItem = TranslatableString(
    en: 'Warehouse item',
    ar: 'صنف المستودع',
    ur: 'گودام آئٹم',
    hi: 'वेयरहाउस आइटम',
  );
  static const availability = TranslatableString(
    en: 'Warehouse availability',
    ar: 'توفر المستودع',
    ur: 'گودام کی دستیابی',
    hi: 'वेयरहाउस उपलब्धता',
  );
  static const reserved = TranslatableString(
    en: 'Reserved',
    ar: 'محجوز',
    ur: 'محفوظ',
    hi: 'आरक्षित',
  );
  static const reason = TranslatableString(
    en: 'Reason / note',
    ar: 'السبب / الملاحظة',
    ur: 'وجہ / نوٹ',
    hi: 'कारण / नोट',
  );
  static const unitCost = TranslatableString(
    en: 'Unit cost',
    ar: 'تكلفة الوحدة',
    ur: 'فی یونٹ لاگت',
    hi: 'इकाई लागत',
  );
  static const procurementNote = TranslatableString(
    en: 'Procurement Note optional',
    ar: 'ملاحظة المشتريات (اختياري)',
    ur: 'پروکیورمنٹ نوٹ (اختیاری)',
    hi: 'खरीद टिप्पणी (वैकल्पिक)',
  );
  static const procurementNoteHint = TranslatableString(
    en: 'Overall availability, alternatives or expected delivery information',
    ar: 'التوفر العام أو البدائل أو معلومات التسليم المتوقعة',
    ur: 'مجموعی دستیابی، متبادل یا متوقع ڈیلیوری کی معلومات',
    hi: 'कुल उपलब्धता, विकल्प या अपेक्षित डिलीवरी जानकारी',
  );
  static const noSourceRequired = TranslatableString(
    en: 'No source required',
    ar: 'لا يلزم مصدر',
    ur: 'ماخذ درکار نہیں',
    hi: 'स्रोत आवश्यक नहीं',
  );
  static const reviewSummary = TranslatableString(
    en: 'Review summary',
    ar: 'ملخص المراجعة',
    ur: 'جائزہ خلاصہ',
    hi: 'समीक्षा सारांश',
  );
  static const version = TranslatableString(
    en: 'Version',
    ar: 'الإصدار',
    ur: 'ورژن',
    hi: 'संस्करण',
  );
  static const startedBy = TranslatableString(
    en: 'Started by',
    ar: 'بدأ بواسطة',
    ur: 'شروع کرنے والا',
    hi: 'शुरू करने वाला',
  );
  static const noArrangement = TranslatableString(
    en: 'No arrangement has been started for this request.',
    ar: 'لم يبدأ أي ترتيب لهذا الطلب.',
    ur: 'اس درخواست کے لیے کوئی انتظام شروع نہیں ہوا۔',
    hi: 'इस अनुरोध के लिए कोई व्यवस्था शुरू नहीं हुई है।',
  );
  static const savingFailed = TranslatableString(
    en: 'Could not save this arrangement. Refresh and review the current version.',
    ar: 'تعذر حفظ هذا الترتيب. حدّث وراجع الإصدار الحالي.',
    ur: 'یہ انتظام محفوظ نہیں ہو سکا۔ ریفریش کریں اور موجودہ ورژن دیکھیں۔',
    hi: 'यह व्यवस्था सहेजी नहीं जा सकी। रीफ़्रेश करके वर्तमान संस्करण देखें।',
  );
  static const invalidLines = TranslatableString(
    en: 'Complete every line. Partial and unavailable decisions need a reason.',
    ar: 'أكمل كل بند. القرارات الجزئية وغير المتاحة تحتاج سببًا.',
    ur: 'ہر سطر مکمل کریں۔ جزوی اور غیر دستیاب فیصلوں کے لیے وجہ ضروری ہے۔',
    hi: 'हर पंक्ति पूरी करें। आंशिक और अनुपलब्ध निर्णयों के लिए कारण चाहिए।',
  );

  static TranslatableString invalidQuantityFor(String line) =>
      TranslatableString(
        en: '$line needs a valid arranged quantity.',
        ar: 'يحتاج $line إلى كمية مرتبة صالحة.',
        ur: '$line کے لیے درست ترتیب شدہ مقدار درکار ہے۔',
        hi: '$line के लिए मान्य व्यवस्थित मात्रा आवश्यक है।',
      );

  static TranslatableString unavailableReasonFor(
    String line,
  ) => TranslatableString(
    en: '$line must have quantity 0 and a reason when it cannot be provided.',
    ar: 'يجب أن تكون كمية $line صفرًا مع سبب عند تعذر التوفير.',
    ur: 'فراہم نہ ہونے کی صورت میں $line کی مقدار 0 اور وجہ ضروری ہے۔',
    hi: 'उपलब्ध न होने पर $line की मात्रा 0 और कारण आवश्यक है।',
  );

  static TranslatableString warehouseItemRequiredFor(String line) =>
      TranslatableString(
        en: '$line needs a warehouse item before it can be reserved.',
        ar: 'يحتاج $line إلى صنف مستودع قبل حجزه.',
        ur: '$line کو ریزرو کرنے سے پہلے گودام کی آئٹم درکار ہے۔',
        hi: '$line को आरक्षित करने से पहले वेयरहाउस आइटम चाहिए।',
      );

  static TranslatableString emptyWarehouseFor(
    String line,
  ) => TranslatableString(
    en: 'Warehouse inventory is empty. Select External supplier and enter a supplier for $line.',
    ar: 'مخزون المستودع فارغ. اختر موردًا خارجيًا وأدخل المورد لـ $line.',
    ur: 'گودام کا ذخیرہ خالی ہے۔ بیرونی سپلائر منتخب کریں اور $line کے لیے سپلائر درج کریں۔',
    hi: 'वेयरहाउस इन्वेंट्री खाली है। बाहरी सप्लायर चुनें और $line के लिए सप्लायर दर्ज करें।',
  );

  static TranslatableString supplierRequiredFor(String line) =>
      TranslatableString(
        en: '$line needs an external supplier name.',
        ar: 'يحتاج $line إلى اسم المورد الخارجي.',
        ur: '$line کے لیے بیرونی سپلائر کا نام درکار ہے۔',
        hi: '$line के लिए बाहरी सप्लायर नाम चाहिए।',
      );

  static TranslatableString partialReasonFor(String line) => TranslatableString(
    en: '$line needs a reason for a partial decision.',
    ar: 'يحتاج $line إلى سبب للقرار الجزئي.',
    ur: '$line کے جزوی فیصلے کے لیے وجہ درکار ہے۔',
    hi: '$line के आंशिक निर्णय के लिए कारण चाहिए।',
  );

  static TranslatableString fullQuantityFor(String line) => TranslatableString(
    en: '$line must match the requested quantity when marked Full.',
    ar: 'يجب أن تطابق كمية $line الكمية المطلوبة عند اختيار كامل.',
    ur: 'مکمل منتخب ہونے پر $line کی مقدار مطلوبہ مقدار کے برابر ہونی چاہیے۔',
    hi: 'Full चुनने पर $line की मात्रा अनुरोधित मात्रा के बराबर होनी चाहिए।',
  );

  static TranslatableString partialQuantityFor(
    String line,
  ) => TranslatableString(
    en: '$line must be greater than zero and less than the requested quantity when marked Partial.',
    ar: 'يجب أن تكون كمية $line أكبر من صفر وأقل من المطلوبة عند اختيار جزئي.',
    ur: 'جزوی منتخب ہونے پر $line کی مقدار صفر سے زیادہ اور مطلوبہ مقدار سے کم ہونی چاہیے۔',
    hi: 'Partial चुनने पर $line की मात्रा शून्य से अधिक और अनुरोधित मात्रा से कम होनी चाहिए।',
  );

  static TranslatableString invalidUnitCostFor(String line) =>
      TranslatableString(
        en: '$line needs a valid non-negative unit cost, or leave it blank.',
        ar: 'يحتاج $line إلى تكلفة وحدة صالحة غير سالبة أو اتركها فارغة.',
        ur: '$line کے لیے درست غیر منفی یونٹ لاگت درج کریں یا خالی چھوڑ دیں۔',
        hi: '$line के लिए वैध गैर-नकारात्मक यूनिट लागत दें या खाली छोड़ दें।',
      );
}

TranslatableString yorksV1ArrangementSourceCopy(
  YorksV1ArrangementSource source,
) => switch (source) {
  YorksV1ArrangementSource.warehouse => YorksV1ArrangementStrings.warehouse,
  YorksV1ArrangementSource.externalSupplier =>
    YorksV1ArrangementStrings.externalSupplier,
};

TranslatableString yorksV1ArrangementDecisionCopy(
  YorksV1ArrangementDecision decision,
) => switch (decision) {
  YorksV1ArrangementDecision.full => const TranslatableString(
    en: 'Full',
    ar: 'كامل',
    ur: 'مکمل',
    hi: 'पूर्ण',
  ),
  YorksV1ArrangementDecision.partial => const TranslatableString(
    en: 'Partial',
    ar: 'جزئي',
    ur: 'جزوی',
    hi: 'आंशिक',
  ),
  YorksV1ArrangementDecision.unavailable => const TranslatableString(
    en: 'Cannot Provide Now',
    ar: 'لا يمكن التوفير الآن',
    ur: 'ابھی فراہم نہیں ہو سکتا',
    hi: 'अभी उपलब्ध नहीं',
  ),
};

TranslatableString yorksV1ArrangementStatusCopy(
  YorksV1ArrangementStatus status,
) => switch (status) {
  YorksV1ArrangementStatus.working => const TranslatableString(
    en: 'Working',
    ar: 'قيد العمل',
    ur: 'کام جاری ہے',
    hi: 'कार्यरत',
  ),
  YorksV1ArrangementStatus.awaitingApproval => const TranslatableString(
    en: 'Awaiting approval',
    ar: 'بانتظار الموافقة',
    ur: 'منظوری کا انتظار',
    hi: 'मंजूरी की प्रतीक्षा',
  ),
  YorksV1ArrangementStatus.approved => const TranslatableString(
    en: 'Approved',
    ar: 'معتمد',
    ur: 'منظور شدہ',
    hi: 'स्वीकृत',
  ),
  YorksV1ArrangementStatus.returned => const TranslatableString(
    en: 'Returned for changes',
    ar: 'أعيد للتعديل',
    ur: 'تبدیلی کے لیے واپس',
    hi: 'बदलाव के लिए लौटाया',
  ),
  YorksV1ArrangementStatus.superseded => const TranslatableString(
    en: 'Replaced',
    ar: 'تم استبداله',
    ur: 'تبدیل شدہ',
    hi: 'प्रतिस्थापित',
  ),
  YorksV1ArrangementStatus.cancelled => const TranslatableString(
    en: 'Cancelled',
    ar: 'ملغى',
    ur: 'منسوخ',
    hi: 'रद्द',
  ),
};
