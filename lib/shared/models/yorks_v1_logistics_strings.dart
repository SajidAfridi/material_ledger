import 'app_strings.dart';
import 'yorks_v1_company_document_strings.dart';
import 'yorks_v1_logistics.dart';

/// Centralized user-facing copy for the Batch 7 warehouse and logistics flow.
abstract final class YorksV1LogisticsStrings {
  static const companyName = YorksV1CompanyDocumentStrings.legalName;
  static const deliveryOrderTitle = TranslatableString(
    en: 'DELIVERY ORDER',
    ar: 'أمر تسليم',
    ur: 'ڈیلیوری آرڈر',
    hi: 'डिलीवरी ऑर्डर',
  );
  static const reference = TranslatableString(
    en: 'Ref.',
    ar: 'المرجع',
    ur: 'حوالہ',
    hi: 'संदर्भ',
  );
  static const date = TranslatableString(
    en: 'Date',
    ar: 'التاريخ',
    ur: 'تاریخ',
    hi: 'दिनांक',
  );
  static const recipient = TranslatableString(
    en: 'M/s.',
    ar: 'السادة',
    ur: 'برائے',
    hi: 'प्रति',
  );
  static const deliveryAddress = TranslatableString(
    en: 'Delivery Address',
    ar: 'عنوان التسليم',
    ur: 'ڈیلیوری کا پتہ',
    hi: 'डिलीवरी पता',
  );
  static const inspectedAndChecked = TranslatableString(
    en: 'Inspected & checked by Yorks',
    ar: 'تم الفحص والتحقق بواسطة يوركس',
    ur: 'Yorks نے معائنہ اور جانچ کی',
    hi: 'Yorks द्वारा निरीक्षण और जाँच',
  );
  static const receiverName = TranslatableString(
    en: "Receiver's Name",
    ar: 'اسم المستلم',
    ur: 'وصول کنندہ کا نام',
    hi: 'प्राप्तकर्ता का नाम',
  );
  static const signature = TranslatableString(
    en: 'Signature / Date',
    ar: 'التوقيع / التاريخ',
    ur: 'دستخط / تاریخ',
    hi: 'हस्ताक्षर / दिनांक',
  );
  static const goodsReceivedInGoodCondition = TranslatableString(
    en: 'GOODS RECEIVED IN GOOD CONDITION',
    ar: 'تم استلام البضائع بحالة جيدة',
    ur: 'سامان اچھی حالت میں وصول ہوا',
    hi: 'सामान अच्छी स्थिति में प्राप्त हुआ',
  );
  static const serialNumber = TranslatableString(
    en: 'S:No',
    ar: 'م',
    ur: 'نمبر',
    hi: 'क्र.',
  );
  static const deliveryQuantity = TranslatableString(
    en: 'Qty',
    ar: 'الكمية',
    ur: 'مقدار',
    hi: 'मात्रा',
  );
  static const state = TranslatableString(
    en: 'State',
    ar: 'الحالة',
    ur: 'حالت',
    hi: 'स्थिति',
  );
  static const draftedBy = TranslatableString(
    en: 'Drafted by',
    ar: 'أعده',
    ur: 'تیار کنندہ',
    hi: 'ड्राफ़्ट करने वाला',
  );
  static const inventory = TranslatableString(
    en: 'Warehouse inventory',
    ar: 'مخزون المستودع',
    ur: 'گودام کا ذخیرہ',
    hi: 'वेयरहाउस इन्वेंटरी',
  );
  static const refresh = TranslatableString(
    en: 'Refresh',
    ar: 'تحديث',
    ur: 'ریفریش',
    hi: 'रीफ़्रेश',
  );
  static const dispatchAndReceipt = TranslatableString(
    en: 'Dispatch and receipt',
    ar: 'الإرسال والاستلام',
    ur: 'ڈسپیچ اور وصولی',
    hi: 'डिस्पैच और प्राप्ति',
  );
  static const project = TranslatableString(
    en: 'Project',
    ar: 'المشروع',
    ur: 'پروجیکٹ',
    hi: 'परियोजना',
  );
  static const scope = TranslatableString(
    en: 'Building / scope',
    ar: 'المبنى / النطاق',
    ur: 'عمارت / دائرہ',
    hi: 'भवन / दायरा',
  );
  static const searchInventory = TranslatableString(
    en: 'Search inventory',
    ar: 'بحث في المخزون',
    ur: 'ذخیرہ تلاش کریں',
    hi: 'इन्वेंटरी खोजें',
  );
  static const addStock = TranslatableString(
    en: 'Add or adjust stock',
    ar: 'إضافة أو تعديل المخزون',
    ur: 'اسٹاک شامل یا ایڈجسٹ کریں',
    hi: 'स्टॉक जोड़ें या समायोजित करें',
  );
  static const itemDescription = TranslatableString(
    en: 'Item Description',
    ar: 'وصف الصنف',
    ur: 'آئٹم کی تفصیل',
    hi: 'आइटम विवरण',
  );
  static const brandOrigin = TranslatableString(
    en: 'Brand / origin',
    ar: 'العلامة / المنشأ',
    ur: 'برانڈ / ماخذ',
    hi: 'ब्रांड / मूल',
  );
  static const unit = TranslatableString(
    en: 'Unit',
    ar: 'الوحدة',
    ur: 'یونٹ',
    hi: 'इकाई',
  );
  static const quantity = TranslatableString(
    en: 'Quantity',
    ar: 'الكمية',
    ur: 'مقدار',
    hi: 'मात्रा',
  );
  static const reason = TranslatableString(
    en: 'Reason',
    ar: 'السبب',
    ur: 'وجہ',
    hi: 'कारण',
  );
  static const onHand = TranslatableString(
    en: 'On hand',
    ar: 'المتوفر فعلياً',
    ur: 'موجودہ اسٹاک',
    hi: 'हाथ में',
  );
  static const reserved = TranslatableString(
    en: 'Reserved',
    ar: 'محجوز',
    ur: 'محفوظ',
    hi: 'आरक्षित',
  );
  static const available = TranslatableString(
    en: 'Available',
    ar: 'المتاح',
    ur: 'دستیاب',
    hi: 'उपलब्ध',
  );
  static const movementHistory = TranslatableString(
    en: 'Movement history',
    ar: 'سجل الحركات',
    ur: 'حرکت کی تاریخ',
    hi: 'मूवमेंट इतिहास',
  );
  static const archive = TranslatableString(
    en: 'Archive item',
    ar: 'أرشفة الصنف',
    ur: 'آئٹم آرکائیو کریں',
    hi: 'आइटम संग्रहित करें',
  );
  static const reactivate = TranslatableString(
    en: 'Reactivate item',
    ar: 'إعادة تفعيل الصنف',
    ur: 'آئٹم دوبارہ فعال کریں',
    hi: 'आइटम फिर सक्रिय करें',
  );
  static const noInventory = TranslatableString(
    en: 'No warehouse items match this search.',
    ar: 'لا توجد أصناف مستودع مطابقة لهذا البحث.',
    ur: 'اس تلاش سے کوئی گودام آئٹم نہیں ملا۔',
    hi: 'इस खोज से कोई वेयरहाउस आइटम नहीं मिला।',
  );
  static const dispatchNow = TranslatableString(
    en: 'Dispatch now',
    ar: 'إرسال الآن',
    ur: 'ابھی ڈسپیچ کریں',
    hi: 'अभी डिस्पैच करें',
  );
  static const dispatchApprovedItems = TranslatableString(
    en: 'Dispatch Approved Items',
    ar: 'إرسال العناصر المعتمدة',
    ur: 'منظور شدہ آئٹمز ڈسپیچ کریں',
    hi: 'स्वीकृत वस्तुएँ भेजें',
  );
  static const dispatched = TranslatableString(
    en: 'dispatched',
    ar: 'تم إرساله',
    ur: 'ڈسپیچ کیا گیا',
    hi: 'भेजा गया',
  );
  static const dispatchDate = TranslatableString(
    en: 'Dispatch date',
    ar: 'تاريخ الإرسال',
    ur: 'ڈسپیچ تاریخ',
    hi: 'डिस्पैच तारीख',
  );
  static const deliveryReference = TranslatableString(
    en: 'Delivery Note / Dispatch Ref.',
    ar: 'مرجع إذن التسليم / الإرسال',
    ur: 'ڈیلیوری نوٹ / ڈسپیچ حوالہ',
    hi: 'डिलीवरी नोट / डिस्पैच रेफ़रेंस',
  );
  static const deliveryReferenceRequired = TranslatableString(
    en: 'Enter the Delivery Note / Dispatch Reference before dispatching.',
    ar: 'أدخل مرجع إذن التسليم / الإرسال قبل الإرسال.',
    ur: 'ڈسپیچ سے پہلے ڈیلیوری نوٹ / ڈسپیچ حوالہ درج کریں۔',
    hi: 'डिस्पैच करने से पहले डिलीवरी नोट / डिस्पैच रेफ़रेंस दर्ज करें।',
  );
  static const driver = TranslatableString(
    en: 'Driver (optional)',
    ar: 'السائق (اختياري)',
    ur: 'ڈرائیور (اختیاری)',
    hi: 'ड्राइवर (वैकल्पिक)',
  );
  static const vehicle = TranslatableString(
    en: 'Vehicle (optional)',
    ar: 'المركبة (اختيارية)',
    ur: 'گاڑی (اختیاری)',
    hi: 'वाहन (वैकल्पिक)',
  );
  static const approved = TranslatableString(
    en: 'Approved',
    ar: 'معتمد',
    ur: 'منظور شدہ',
    hi: 'स्वीकृत',
  );
  static const goodReceived = TranslatableString(
    en: 'Good received',
    ar: 'المستلم السليم',
    ur: 'درست وصول شدہ',
    hi: 'अच्छी तरह प्राप्त',
  );
  static const inTransit = TranslatableString(
    en: 'In transit',
    ar: 'قيد النقل',
    ur: 'راستے میں',
    hi: 'पारगमन में',
  );
  static const stillNeeded = TranslatableString(
    en: 'Still needed',
    ar: 'ما زال مطلوباً',
    ur: 'اب بھی درکار',
    hi: 'अभी भी आवश्यक',
  );
  static const dispatchQuantity = TranslatableString(
    en: 'Dispatch now',
    ar: 'الكمية المراد إرسالها',
    ur: 'ابھی ڈسپیچ کی مقدار',
    hi: 'अब भेजने की मात्रा',
  );
  static const dispatchHistory = TranslatableString(
    en: 'Dispatch history',
    ar: 'سجل الإرسال',
    ur: 'ڈسپیچ کی تاریخ',
    hi: 'डिस्पैच इतिहास',
  );
  static const receiptReview = TranslatableString(
    en: 'Receipt review',
    ar: 'مراجعة الاستلام',
    ur: 'وصولی کا جائزہ',
    hi: 'प्राप्ति समीक्षा',
  );
  static const reviewAndMarkReceived = TranslatableString(
    en: 'Review & Mark Received',
    ar: 'مراجعة وتأكيد الاستلام',
    ur: 'جائزہ لے کر موصول شدہ نشان زد کریں',
    hi: 'समीक्षा करें और प्राप्त के रूप में चिह्नित करें',
  );
  static const reviewDeliveredMaterials = TranslatableString(
    en: 'Review delivered materials',
    ar: 'مراجعة المواد المسلّمة',
    ur: 'پہنچائے گئے مواد کا جائزہ لیں',
    hi: 'वितरित सामग्री की समीक्षा करें',
  );
  static const reviewDeliveryLineByLine = TranslatableString(
    en: 'Check every line against the physical receipt.',
    ar: 'تحقق من كل بند مقابل الاستلام الفعلي.',
    ur: 'ہر لائن کو موصول شدہ اصل مواد کے ساتھ چیک کریں۔',
    hi: 'हर पंक्ति को वास्तविक प्राप्ति के विरुद्ध जांचें।',
  );
  static const saveReceiptReview = TranslatableString(
    en: 'Save receipt review',
    ar: 'حفظ مراجعة الاستلام',
    ur: 'وصولی کا جائزہ محفوظ کریں',
    hi: 'प्राप्ति समीक्षा सहेजें',
  );
  static const confirmReceipt = TranslatableString(
    en: 'Confirm receipt review',
    ar: 'تأكيد مراجعة الاستلام',
    ur: 'وصولی کا جائزہ تصدیق کریں',
    hi: 'प्राप्ति समीक्षा की पुष्टि करें',
  );
  static const allLinesReviewed = TranslatableString(
    en: 'All dispatch lines have been reviewed.',
    ar: 'تمت مراجعة جميع بنود الإرسال.',
    ur: 'تمام ڈسپیچ لائنز کا جائزہ لیا گیا ہے۔',
    hi: 'सभी डिस्पैच पंक्तियों की समीक्षा की गई है।',
  );
  static const outcome = TranslatableString(
    en: 'Outcome',
    ar: 'النتيجة',
    ur: 'نتیجہ',
    hi: 'परिणाम',
  );
  static const goodQuantity = TranslatableString(
    en: 'Good quantity',
    ar: 'الكمية السليمة',
    ur: 'درست مقدار',
    hi: 'अच्छी मात्रा',
  );
  static const note = TranslatableString(
    en: 'Note',
    ar: 'ملاحظة',
    ur: 'نوٹ',
    hi: 'नोट',
  );
  static const exceptionNote = TranslatableString(
    en: 'Line note (required for missing or damaged)',
    ar: 'ملاحظة البند (مطلوبة للنقص أو التلف)',
    ur: 'لائن نوٹ (گم یا خراب ہونے پر ضروری)',
    hi: 'लाइन नोट (लापता या क्षतिग्रस्त होने पर आवश्यक)',
  );
  static const noDispatch = TranslatableString(
    en: 'No committed dispatches yet.',
    ar: 'لا توجد عمليات إرسال معتمدة حتى الآن.',
    ur: 'ابھی تک کوئی تصدیق شدہ ڈسپیچ نہیں۔',
    hi: 'अभी तक कोई प्रतिबद्ध डिस्पैच नहीं।',
  );
  static const savingFailed = TranslatableString(
    en: 'This operation could not be saved. Refresh and review the current state.',
    ar: 'تعذر حفظ العملية. حدّث وراجع الحالة الحالية.',
    ur: 'یہ عمل محفوظ نہیں ہو سکا۔ ریفریش کریں اور موجودہ حالت دیکھیں۔',
    hi: 'यह कार्रवाई सहेजी नहीं जा सकी। रीफ्रेश करके वर्तमान स्थिति देखें।',
  );
  static const invalidDispatch = TranslatableString(
    en: 'Enter a positive quantity for at least one line.',
    ar: 'أدخل كمية موجبة لبند واحد على الأقل.',
    ur: 'کم از کم ایک لائن کے لیے مثبت مقدار درج کریں۔',
    hi: 'कम से कम एक पंक्ति के लिए धनात्मक मात्रा दर्ज करें।',
  );
  static const invalidReceipt = TranslatableString(
    en: 'Review every line. Missing and damaged lines need a note.',
    ar: 'راجع كل بند. البنود الناقصة أو التالفة تحتاج ملاحظة.',
    ur: 'ہر لائن کا جائزہ لیں۔ گم یا خراب لائنوں کے لیے نوٹ ضروری ہے۔',
    hi: 'हर पंक्ति की समीक्षा करें। लापता और क्षतिग्रस्त पंक्तियों के लिए नोट आवश्यक है।',
  );
  static const deliveryOrdersAndReturns = TranslatableString(
    en: 'Delivery Orders and returns',
    ar: 'أوامر التسليم والمرتجعات',
    ur: 'ڈیلیوری آرڈرز اور واپسی',
    hi: 'डिलीवरी ऑर्डर और वापसी',
  );
  static const deliveryOrders = TranslatableString(
    en: 'Delivery Orders',
    ar: 'أوامر التسليم',
    ur: 'ڈیلیوری آرڈرز',
    hi: 'डिलीवरी ऑर्डर',
  );
  static const deliveryOrder = TranslatableString(
    en: 'Delivery Order',
    ar: 'أمر التسليم',
    ur: 'ڈیلیوری آرڈر',
    hi: 'डिलीवरी ऑर्डर',
  );
  static const deliveryOrderReference = TranslatableString(
    en: 'Delivery Order reference',
    ar: 'مرجع أمر التسليم',
    ur: 'ڈیلیوری آرڈر حوالہ',
    hi: 'डिलीवरी ऑर्डर संदर्भ',
  );
  static const deliveryOrderReferenceRequired = TranslatableString(
    en: 'Enter the official Delivery Order reference.',
    ar: 'أدخل مرجع أمر التسليم الرسمي.',
    ur: 'سرکاری ڈیلیوری آرڈر حوالہ درج کریں۔',
    hi: 'आधिकारिक डिलीवरी ऑर्डर संदर्भ दर्ज करें।',
  );
  static const deliveryOrderAfterReceipt = TranslatableString(
    en: 'The immutable Delivery Order includes committed dispatched quantities.',
    ar: 'يتضمن أمر التسليم غير القابل للتعديل كميات الإرسال المعتمدة.',
    ur: 'ناقابلِ ترمیم ڈیلیوری آرڈر میں تصدیق شدہ ڈسپیچ مقدار شامل ہوتی ہے۔',
    hi: 'अपरिवर्तनीय डिलीवरी ऑर्डर में पुष्ट डिस्पैच मात्राएँ शामिल होती हैं।',
  );
  static const generateDeliveryOrder = TranslatableString(
    en: 'Generate Delivery Order',
    ar: 'إنشاء أمر التسليم',
    ur: 'ڈیلیوری آرڈر بنائیں',
    hi: 'डिलीवरी ऑर्डर बनाएं',
  );
  static const regenerateDeliveryOrder = TranslatableString(
    en: 'Create new revision',
    ar: 'إنشاء مراجعة جديدة',
    ur: 'نیا ورژن بنائیں',
    hi: 'नया संशोधन बनाएं',
  );
  static const revision = TranslatableString(
    en: 'Revision',
    ar: 'المراجعة',
    ur: 'ورژن',
    hi: 'संशोधन',
  );
  static const noDeliveryOrders = TranslatableString(
    en: 'No receipt-reviewed dispatches are available yet.',
    ar: 'لا توجد عمليات إرسال تمت مراجعة استلامها بعد.',
    ur: 'ابھی کوئی وصولی شدہ ڈسپیچ دستیاب نہیں ہے۔',
    hi: 'अभी तक कोई प्राप्ति-समीक्षित डिस्पैच उपलब्ध नहीं है।',
  );
  static const exportExcel = TranslatableString(
    en: 'Excel',
    ar: 'إكسل',
    ur: 'ایکسل',
    hi: 'एक्सेल',
  );
  static const printDocument = TranslatableString(
    en: 'Print / PDF',
    ar: 'طباعة / PDF',
    ur: 'پرنٹ / PDF',
    hi: 'प्रिंट / PDF',
  );
  static const downloadPdf = TranslatableString(
    en: 'Download PDF',
    ar: 'تنزيل PDF',
    ur: 'PDF ڈاؤن لوڈ کریں',
    hi: 'PDF डाउनलोड करें',
  );
  static const materialReturns = TranslatableString(
    en: 'Material returns',
    ar: 'مرتجعات المواد',
    ur: 'میٹریل واپسی',
    hi: 'सामग्री वापसी',
  );
  static const eligibleToReturn = TranslatableString(
    en: 'Eligible to return',
    ar: 'المتاح للإرجاع',
    ur: 'واپسی کے لیے اہل',
    hi: 'वापसी के लिए योग्य',
  );
  static const returnQuantity = TranslatableString(
    en: 'Return quantity',
    ar: 'كمية الإرجاع',
    ur: 'واپسی کی مقدار',
    hi: 'वापसी मात्रा',
  );
  static const returnNote = TranslatableString(
    en: 'Return note (optional)',
    ar: 'ملاحظة الإرجاع (اختيارية)',
    ur: 'واپسی نوٹ (اختیاری)',
    hi: 'वापसी नोट (वैकल्पिक)',
  );
  static const saveReturnDraft = TranslatableString(
    en: 'Save return draft',
    ar: 'حفظ مسودة الإرجاع',
    ur: 'واپسی ڈرافٹ محفوظ کریں',
    hi: 'वापसी ड्राफ़्ट सहेजें',
  );
  static const submitReturn = TranslatableString(
    en: 'Submit return',
    ar: 'إرسال الإرجاع',
    ur: 'واپسی جمع کرائیں',
    hi: 'वापसी जमा करें',
  );
  static const confirmReturn = TranslatableString(
    en: 'Confirm warehouse return',
    ar: 'تأكيد إرجاع المستودع',
    ur: 'گودام واپسی کی تصدیق کریں',
    hi: 'वेयरहाउस वापसी की पुष्टि करें',
  );
  static const rejectReturn = TranslatableString(
    en: 'Reject return',
    ar: 'رفض الإرجاع',
    ur: 'واپسی مسترد کریں',
    hi: 'वापसी अस्वीकार करें',
  );
  static const rejectionReason = TranslatableString(
    en: 'Rejection reason',
    ar: 'سبب الرفض',
    ur: 'مسترد کرنے کی وجہ',
    hi: 'अस्वीकृति का कारण',
  );
  static const newInventoryItem = TranslatableString(
    en: 'Create identified inventory item',
    ar: 'إنشاء صنف مخزون محدد',
    ur: 'شناخت شدہ انوینٹری آئٹم بنائیں',
    hi: 'पहचानी गई इन्वेंटरी वस्तु बनाएं',
  );
  static const mapInventoryItem = TranslatableString(
    en: 'Map to inventory item',
    ar: 'ربط بصنف المخزون',
    ur: 'انوینٹری آئٹم سے منسلک کریں',
    hi: 'इन्वेंटरी आइटम से जोड़ें',
  );
  static const noEligibleReturns = TranslatableString(
    en: 'No good received quantity is currently eligible for return.',
    ar: 'لا توجد كمية مستلمة سليمة متاحة للإرجاع حالياً.',
    ur: 'اس وقت کوئی درست وصول شدہ مقدار واپسی کے لیے اہل نہیں ہے۔',
    hi: 'वर्तमान में वापसी के लिए कोई अच्छी प्राप्त मात्रा योग्य नहीं है।',
  );
  static const noMaterialReturns = TranslatableString(
    en: 'No material returns have been prepared.',
    ar: 'لم يتم إعداد أي مرتجعات مواد.',
    ur: 'ابھی کوئی میٹریل واپسی تیار نہیں کی گئی۔',
    hi: 'अभी तक कोई सामग्री वापसी तैयार नहीं की गई है।',
  );
  static const invalidReturn = TranslatableString(
    en: 'Enter a positive quantity that does not exceed the eligible amount.',
    ar: 'أدخل كمية موجبة لا تتجاوز الكمية المتاحة.',
    ur: 'مثبت مقدار درج کریں جو اہل مقدار سے زیادہ نہ ہو۔',
    hi: 'ऐसी धनात्मक मात्रा दर्ज करें जो योग्य राशि से अधिक न हो।',
  );
}

TranslatableString yorksV1LogisticsSourceCopy(YorksV1LogisticsSource source) =>
    switch (source) {
      YorksV1LogisticsSource.warehouse => const TranslatableString(
        en: 'Warehouse',
        ar: 'المستودع',
        ur: 'گودام',
        hi: 'वेयरहाउस',
      ),
      YorksV1LogisticsSource.externalSupplier => const TranslatableString(
        en: 'External supplier',
        ar: 'مورد خارجي',
        ur: 'بیرونی سپلائر',
        hi: 'बाहरी आपूर्तिकर्ता',
      ),
    };

TranslatableString yorksV1DispatchStateCopy(YorksV1DispatchState state) =>
    switch (state) {
      YorksV1DispatchState.receiptPending => const TranslatableString(
        en: 'Receipt review required',
        ar: 'مراجعة الاستلام مطلوبة',
        ur: 'وصولی کا جائزہ درکار',
        hi: 'प्राप्ति समीक्षा आवश्यक',
      ),
      YorksV1DispatchState.partiallyReceived => const TranslatableString(
        en: 'Partially received',
        ar: 'مستلم جزئياً',
        ur: 'جزوی وصولی',
        hi: 'आंशिक रूप से प्राप्त',
      ),
      YorksV1DispatchState.received => const TranslatableString(
        en: 'Received',
        ar: 'تم الاستلام',
        ur: 'وصول شدہ',
        hi: 'प्राप्त',
      ),
    };

TranslatableString yorksV1ReceiptOutcomeCopy(YorksV1ReceiptOutcome outcome) =>
    switch (outcome) {
      YorksV1ReceiptOutcome.received => const TranslatableString(
        en: 'Received',
        ar: 'مستلم',
        ur: 'وصول شدہ',
        hi: 'प्राप्त',
      ),
      YorksV1ReceiptOutcome.missing => const TranslatableString(
        en: 'Missing',
        ar: 'ناقص',
        ur: 'گمشدہ',
        hi: 'लापता',
      ),
      YorksV1ReceiptOutcome.damaged => const TranslatableString(
        en: 'Damaged',
        ar: 'تالف',
        ur: 'خراب',
        hi: 'क्षतिग्रस्त',
      ),
    };

TranslatableString yorksV1MaterialReturnStateCopy(
  YorksV1MaterialReturnState state,
) => switch (state) {
  YorksV1MaterialReturnState.draft => const TranslatableString(
    en: 'Draft',
    ar: 'مسودة',
    ur: 'ڈرافٹ',
    hi: 'ड्राफ़्ट',
  ),
  YorksV1MaterialReturnState.submitted => const TranslatableString(
    en: 'Submitted',
    ar: 'مرسل',
    ur: 'جمع شدہ',
    hi: 'जमा किया गया',
  ),
  YorksV1MaterialReturnState.confirmed => const TranslatableString(
    en: 'Confirmed',
    ar: 'مؤكد',
    ur: 'تصدیق شدہ',
    hi: 'पुष्ट',
  ),
  YorksV1MaterialReturnState.rejected => const TranslatableString(
    en: 'Rejected',
    ar: 'مرفوض',
    ur: 'مسترد',
    hi: 'अस्वीकृत',
  ),
};
