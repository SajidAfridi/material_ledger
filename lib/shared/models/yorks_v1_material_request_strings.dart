import 'app_strings.dart';
import 'yorks_v1_domain_error.dart';
import 'yorks_v1_company_document_strings.dart';
import 'yorks_v1_material_request.dart';

/// Centralized bilingual-capable presentation copy for the Yorks V1 Material
/// Request slice. Domain and database layers use stable codes, never this copy.
abstract final class YorksV1MaterialRequestStrings {
  static const connectToContinue = TranslatableString(
    en: 'Connect to the server and try again.',
    ar: 'اتصل بالخادم وحاول مرة أخرى.',
    ur: 'سرور سے جڑیں اور دوبارہ کوشش کریں۔',
    hi: 'सर्वर से जुड़ें और फिर प्रयास करें।',
  );
  static const actionNotAllowed = TranslatableString(
    en: 'You are not allowed to complete this action.',
    ar: 'غير مسموح لك بإكمال هذا الإجراء.',
    ur: 'آپ کو یہ عمل مکمل کرنے کی اجازت نہیں ہے۔',
    hi: 'आपको यह कार्रवाई पूरी करने की अनुमति नहीं है।',
  );
  static const recordChanged = TranslatableString(
    en: 'This record changed. Refresh it before trying again.',
    ar: 'تم تغيير هذا السجل. قم بتحديثه قبل المحاولة مرة أخرى.',
    ur: 'یہ ریکارڈ بدل گیا ہے۔ دوبارہ کوشش سے پہلے اسے ریفریش کریں۔',
    hi: 'यह रिकॉर्ड बदल गया है। फिर प्रयास करने से पहले इसे रीफ़्रेश करें।',
  );
  static const invalidWorkflowInput = TranslatableString(
    en: 'Review the entered values and try again.',
    ar: 'راجع القيم المدخلة وحاول مرة أخرى.',
    ur: 'درج کی گئی اقدار کا جائزہ لیں اور دوبارہ کوشش کریں۔',
    hi: 'दर्ज किए गए मानों की समीक्षा करें और फिर प्रयास करें।',
  );
  static const actionFailed = TranslatableString(
    en: 'The server could not confirm this action. Try again safely.',
    ar: 'تعذر على الخادم تأكيد هذا الإجراء. حاول مرة أخرى بأمان.',
    ur: 'سرور اس عمل کی تصدیق نہیں کر سکا۔ محفوظ طریقے سے دوبارہ کوشش کریں۔',
    hi: 'सर्वर इस कार्रवाई की पुष्टि नहीं कर सका। सुरक्षित रूप से फिर प्रयास करें।',
  );
  static const insufficientStock = TranslatableString(
    en: 'Warehouse stock changed and is no longer sufficient. Refresh before dispatching again.',
    ar: 'تغير مخزون المستودع ولم يعد كافياً. حدّث البيانات قبل إعادة الإرسال.',
    ur: 'گودام کا اسٹاک بدل گیا ہے اور اب کافی نہیں۔ دوبارہ ڈسپیچ سے پہلے ریفریش کریں۔',
    hi: 'वेयरहाउस स्टॉक बदल गया है और अब पर्याप्त नहीं है। फिर डिस्पैच करने से पहले रीफ़्रेश करें।',
  );
  static const quantityCapExceeded = TranslatableString(
    en: 'This quantity exceeds the approved outstanding amount. Refresh and enter a smaller quantity.',
    ar: 'تتجاوز هذه الكمية الرصيد المعتمد المتبقي. حدّث البيانات وأدخل كمية أقل.',
    ur: 'یہ مقدار منظور شدہ بقایا مقدار سے زیادہ ہے۔ ریفریش کریں اور کم مقدار درج کریں۔',
    hi: 'यह मात्रा स्वीकृत बकाया मात्रा से अधिक है। रीफ़्रेश करें और कम मात्रा दर्ज करें।',
  );
  static const immutableRecord = TranslatableString(
    en: 'This committed reference cannot be changed. Open the existing document instead.',
    ar: 'لا يمكن تغيير هذا المرجع المعتمد. افتح المستند الموجود بدلاً من ذلك.',
    ur: 'اس تصدیق شدہ حوالے کو تبدیل نہیں کیا جا سکتا۔ موجودہ دستاویز کھولیں۔',
    hi: 'इस प्रतिबद्ध संदर्भ को बदला नहीं जा सकता। इसके बजाय मौजूदा दस्तावेज़ खोलें।',
  );
  static const incompleteReview = TranslatableString(
    en: 'Review every dispatched line and add a note for each Missing or Damaged quantity.',
    ar: 'راجع كل بند مُرسل وأضف ملاحظة لكل كمية مفقودة أو تالفة.',
    ur: 'ہر ڈسپیچ لائن کا جائزہ لیں اور ہر گم یا خراب مقدار کے لیے نوٹ شامل کریں۔',
    hi: 'हर भेजी गई पंक्ति की समीक्षा करें और हर गुम या क्षतिग्रस्त मात्रा के लिए टिप्पणी जोड़ें।',
  );

  static TranslatableString commandFailure(YorksV1DomainErrorCode code) =>
      switch (code) {
        YorksV1DomainErrorCode.offline ||
        YorksV1DomainErrorCode.backendUnavailable => connectToContinue,
        YorksV1DomainErrorCode.unauthenticated ||
        YorksV1DomainErrorCode.unauthorized => actionNotAllowed,
        YorksV1DomainErrorCode.conflict => recordChanged,
        YorksV1DomainErrorCode.invalidInput ||
        YorksV1DomainErrorCode.invalidTransition => invalidWorkflowInput,
        YorksV1DomainErrorCode.insufficientStock => insufficientStock,
        YorksV1DomainErrorCode.quantityCapExceeded => quantityCapExceeded,
        YorksV1DomainErrorCode.immutableRecord => immutableRecord,
        YorksV1DomainErrorCode.incompleteReview => incompleteReview,
        _ => actionFailed,
      };

  static const companyName = TranslatableString(
    en: 'Yorks AC. & Ref.',
    ar: 'يوركس للتكييف والتبريد',
    ur: 'یارکس اے سی اینڈ ریف',
    hi: 'यॉर्क्स एसी एंड रेफ.',
  );
  static const companyLegalName = YorksV1CompanyDocumentStrings.legalName;
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
    en: 'Remarks are removed. The item order matches the familiar Yorks Material Request layout.',
    ar: 'تمت إزالة الملاحظات. يطابق ترتيب البنود نموذج طلب مواد Yorks المعتاد.',
    ur: 'ریمارکس ہٹا دیے گئے ہیں۔ آئٹم کی ترتیب Yorks کے مانوس مواد درخواست فارم کے مطابق ہے۔',
    hi: 'टिप्पणियाँ हटा दी गई हैं। आइटम क्रम परिचित Yorks सामग्री अनुरोध फॉर्म से मेल खाता है।',
  );
  static const rowTools = TranslatableString(
    en: 'Row tools',
    ar: 'أدوات الصفوف',
    ur: 'قطار کے ٹولز',
    hi: 'पंक्ति उपकरण',
  );
  static const continueAction = TranslatableString(
    en: 'Continue',
    ar: 'متابعة',
    ur: 'جاری رکھیں',
    hi: 'जारी रखें',
  );
  static const all = TranslatableString(
    en: 'All',
    ar: 'الكل',
    ur: 'سب',
    hi: 'सभी',
  );
  static const back = TranslatableString(
    en: 'Back',
    ar: 'رجوع',
    ur: 'واپس',
    hi: 'वापस',
  );
  static const selectedItems = TranslatableString(
    en: 'Selected items',
    ar: 'العناصر المختارة',
    ur: 'منتخب آئٹمز',
    hi: 'चुनी हुई वस्तुएँ',
  );
  static const noBoqItems = TranslatableString(
    en: 'No BOQ items are available in this scope.',
    ar: 'لا توجد بنود جدول كميات متاحة في هذا النطاق.',
    ur: 'اس اسکوپ میں کوئی BOQ آئٹم دستیاب نہیں ہے۔',
    hi: 'इस दायरे में कोई बीओक्यू आइटम उपलब्ध नहीं है।',
  );
  static const addSelectedItems = TranslatableString(
    en: 'Add Selected Items',
    ar: 'إضافة العناصر المحددة',
    ur: 'منتخب آئٹمز شامل کریں',
    hi: 'चुने हुए आइटम जोड़ें',
  );
  static const selectAll = TranslatableString(
    en: 'Select all',
    ar: 'تحديد الكل',
    ur: 'سب منتخب کریں',
    hi: 'सभी चुनें',
  );
  static const alreadyAdded = TranslatableString(
    en: 'Already added',
    ar: 'تمت إضافته مسبقًا',
    ur: 'پہلے ہی شامل ہے',
    hi: 'पहले से जोड़ा गया',
  );
  static const noBoqMaterialsHelp = TranslatableString(
    en: 'Add or import materials into this scope’s BOQ first, or add a custom item to the request.',
    ar: 'أضف المواد أو استوردها أولًا إلى جدول كميات هذا النطاق، أو أضف عنصرًا مخصصًا إلى الطلب.',
    ur: 'پہلے اس اسکوپ کے BOQ میں مواد شامل یا درآمد کریں، یا درخواست میں کسٹم آئٹم شامل کریں۔',
    hi: 'पहले इस दायरे के BOQ में सामग्री जोड़ें या आयात करें, अथवा अनुरोध में कस्टम आइटम जोड़ें।',
  );
  static const boqScopeOnly = TranslatableString(
    en: 'Only materials from the selected request scope are shown.',
    ar: 'تظهر فقط مواد نطاق الطلب المحدد.',
    ur: 'صرف منتخب درخواست اسکوپ کا مواد دکھایا جاتا ہے۔',
    hi: 'केवल चुने हुए अनुरोध दायरे की सामग्री दिखाई जाती है।',
  );
  static const changeScopeToBrowseBoq = TranslatableString(
    en: 'Change Building / Other in Request Information to browse a different BOQ.',
    ar: 'غيّر المبنى / غيره في معلومات الطلب لاستعراض جدول كميات مختلف.',
    ur: 'مختلف BOQ دیکھنے کے لیے درخواست کی معلومات میں عمارت / دیگر تبدیل کریں۔',
    hi: 'अलग BOQ देखने के लिए अनुरोध जानकारी में भवन / अन्य बदलें।',
  );
  static TranslatableString addItemsFromBoq(String scopeName) =>
      TranslatableString(
        en: 'Add Items from $scopeName BOQ',
        ar: 'إضافة عناصر من جدول كميات $scopeName',
        ur: '$scopeName BOQ سے آئٹمز شامل کریں',
        hi: '$scopeName BOQ से आइटम जोड़ें',
      );
  static TranslatableString noMaterialsInBoq(String scopeName) =>
      TranslatableString(
        en: 'No materials in $scopeName BOQ',
        ar: 'لا توجد مواد في جدول كميات $scopeName',
        ur: '$scopeName BOQ میں کوئی مواد نہیں',
        hi: '$scopeName BOQ में कोई सामग्री नहीं है',
      );
  static TranslatableString selectedItemCount(int count) => TranslatableString(
    en: '$count selected',
    ar: 'تم تحديد $count',
    ur: '$count منتخب',
    hi: '$count चुने गए',
  );
  static const confirmScopeAndLines = TranslatableString(
    en: 'I have reviewed the project scope and requested quantities.',
    ar: 'لقد راجعت نطاق المشروع والكميات المطلوبة.',
    ur: 'میں نے پراجیکٹ اسکوپ اور مطلوبہ مقداروں کا جائزہ لیا ہے۔',
    hi: 'मैंने परियोजना के दायरे और मांगी गई मात्राओं की समीक्षा कर ली है।',
  );
  static const reviewAndSubmit = TranslatableString(
    en: 'Review and submit',
    ar: 'مراجعة وإرسال',
    ur: 'جائزہ لیں اور جمع کرائیں',
    hi: 'समीक्षा करें और जमा करें',
  );
  static const serverConfirmed = TranslatableString(
    en: 'Your request has been submitted and is now with Procurement.',
    ar: 'تم إرسال طلبك وهو الآن لدى المشتريات.',
    ur: 'آپ کی درخواست جمع ہو گئی ہے اور اب پروکیورمنٹ کے پاس ہے۔',
    hi: 'आपका अनुरोध जमा हो गया है और अब खरीद विभाग के पास है।',
  );
  static const viewRequest = TranslatableString(
    en: 'View request',
    ar: 'عرض الطلب',
    ur: 'درخواست دیکھیں',
    hi: 'अनुरोध देखें',
  );
  static const backToRequests = TranslatableString(
    en: 'Back to requests',
    ar: 'العودة إلى الطلبات',
    ur: 'درخواستوں پر واپس جائیں',
    hi: 'अनुरोधों पर वापस जाएँ',
  );
  static const unplannedMaterial = TranslatableString(
    en: 'Custom material',
    ar: 'مادة مخصصة',
    ur: 'کسٹم میٹیریل',
    hi: 'कस्टम सामग्री',
  );
  static const itemAdded = TranslatableString(
    en: 'Item added to this draft.',
    ar: 'تمت إضافة البند إلى هذه المسودة.',
    ur: 'آئٹم اس ڈرافٹ میں شامل کر دی گئی ہے۔',
    hi: 'आइटम इस ड्राफ़्ट में जोड़ दी गई है।',
  );
  static const workflowTimeline = TranslatableString(
    en: 'Workflow timeline',
    ar: 'الجدول الزمني لسير العمل',
    ur: 'ورک فلو ٹائم لائن',
    hi: 'वर्कफ़्लो समय-रेखा',
  );
  static const recentActivity = TranslatableString(
    en: 'Recent activity',
    ar: 'النشاط الأخير',
    ur: 'حالیہ سرگرمی',
    hi: 'हाल की गतिविधि',
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
  static const assignedOnSubmit = TranslatableString(
    en: 'Assigned on submit',
    ar: 'يُعيّن عند الإرسال',
    ur: 'جمع کرانے پر تفویض کیا جائے گا',
    hi: 'सबमिट करने पर असाइन किया जाएगा',
  );
  static const changeProject = TranslatableString(
    en: 'Change project',
    ar: 'تغيير المشروع',
    ur: 'پروجیکٹ تبدیل کریں',
    hi: 'प्रोजेक्ट बदलें',
  );
  static const changeProjectDiscardLines = TranslatableString(
    en: 'Changing the project removes {count} material item(s) from this draft. Continue?',
    ar: 'سيؤدي تغيير المشروع إلى إزالة {count} من بنود المواد من هذه المسودة. هل تريد المتابعة؟',
    ur: 'پروجیکٹ تبدیل کرنے سے اس ڈرافٹ سے {count} میٹیریل آئٹمز ہٹ جائیں گی۔ جاری رکھیں؟',
    hi: 'प्रोजेक्ट बदलने से इस ड्राफ़्ट से {count} सामग्री आइटम हट जाएंगे। जारी रखें?',
  );
  static const changeScope = TranslatableString(
    en: 'Change scope',
    ar: 'تغيير النطاق',
    ur: 'اسکوپ تبدیل کریں',
    hi: 'स्कोप बदलें',
  );
  static const changeScopeDiscardBoqRows = TranslatableString(
    en: 'Changing the scope removes {count} BOQ item(s) from this draft. Custom and imported rows stay. Continue?',
    ar: 'سيؤدي تغيير النطاق إلى إزالة {count} من بنود جدول الكميات من هذه المسودة. ستبقى البنود المخصصة والمستوردة. هل تريد المتابعة؟',
    ur: 'اسکوپ تبدیل کرنے سے اس ڈرافٹ سے {count} BOQ آئٹمز ہٹ جائیں گی۔ کسٹم اور امپورٹڈ قطاریں رہیں گی۔ جاری رکھیں؟',
    hi: 'स्कोप बदलने से इस ड्राफ़्ट से {count} BOQ आइटम हट जाएंगे। कस्टम और आयातित पंक्तियाँ बनी रहेंगी। जारी रखें?',
  );
  static const selectScopeToAddBoq = TranslatableString(
    en: 'Choose a Common or building scope before adding BOQ items.',
    ar: 'اختر نطاقاً مشتركاً أو مبنى قبل إضافة بنود جدول الكميات.',
    ur: 'BOQ آئٹمز شامل کرنے سے پہلے کامن یا بلڈنگ اسکوپ منتخب کریں۔',
    hi: 'BOQ आइटम जोड़ने से पहले कॉमन या बिल्डिंग स्कोप चुनें।',
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
  static const suggestedQuantityReview = TranslatableString(
    en: 'Suggested quantity: 1. Please review before submission.',
    ar: 'الكمية المقترحة: 1. يرجى مراجعتها قبل الإرسال.',
    ur: 'تجویز کردہ مقدار: 1۔ جمع کرانے سے پہلے براہ کرم جائزہ لیں۔',
    hi: 'सुझाई गई मात्रा: 1। सबमिट करने से पहले कृपया जाँच लें।',
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
  static const resumeSavedDraft = TranslatableString(
    en: 'Resume saved draft',
    ar: 'استئناف المسودة المحفوظة',
    ur: 'محفوظ شدہ ڈرافٹ جاری رکھیں',
    hi: 'सहेजा गया ड्राफ़्ट फिर से शुरू करें',
  );
  static const localDraftPrivate = TranslatableString(
    en: 'This unfinished request is private to you on this device. Continue where you left off before creating another request.',
    ar: 'هذا الطلب غير المكتمل خاص بك على هذا الجهاز. تابع من حيث توقفت قبل إنشاء طلب آخر.',
    ur: 'یہ نامکمل درخواست اس ڈیوائس پر صرف آپ کی ہے۔ نئی درخواست بنانے سے پہلے وہیں سے جاری رکھیں جہاں آپ نے چھوڑا تھا۔',
    hi: 'यह अधूरा अनुरोध इस डिवाइस पर केवल आपके लिए है। नया अनुरोध बनाने से पहले वहीं से जारी रखें जहाँ आपने छोड़ा था।',
  );
  static TranslatableString localDraftCount(int count) => TranslatableString(
    en: '$count saved local draft${count == 1 ? '' : 's'}',
    ar: '$count مسودة محلية محفوظة',
    ur: '$count محفوظ مقامی ڈرافٹس',
    hi: '$count सहेजे गए स्थानीय ड्राफ़्ट',
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
  static const arrangeItems = TranslatableString(
    en: 'Arrange Items',
    ar: 'ترتيب العناصر',
    ur: 'آئٹمز ترتیب دیں',
    hi: 'आइटम व्यवस्थित करें',
  );
  static const pdf = TranslatableString(
    en: 'PDF',
    ar: 'PDF',
    ur: 'PDF',
    hi: 'PDF',
  );
  static const print = TranslatableString(
    en: 'Print',
    ar: 'طباعة',
    ur: 'پرنٹ',
    hi: 'प्रिंट',
  );
  static const requestStatus = TranslatableString(
    en: 'Request Status',
    ar: 'حالة الطلب',
    ur: 'درخواست کی حالت',
    hi: 'अनुरोध स्थिति',
  );
  static const requestStatusDescription = TranslatableString(
    en: 'Engineer and Procurement follow the same five-step record.',
    ar: 'يتبع المهندس والمشتريات نفس السجل ذي الخطوات الخمس.',
    ur: 'انجینئر اور پروکیورمنٹ ایک ہی پانچ مرحلے کے ریکارڈ پر عمل کرتے ہیں۔',
    hi: 'इंजीनियर और खरीद विभाग एक ही पांच-चरण रिकॉर्ड का पालन करते हैं।',
  );
  static const request = TranslatableString(
    en: 'Request',
    ar: 'الطلب',
    ur: 'درخواست',
    hi: 'अनुरोध',
  );
  static const procurement = TranslatableString(
    en: 'Procurement',
    ar: 'المشتريات',
    ur: 'پروکیورمنٹ',
    hi: 'खरीद',
  );
  static const dispatch = TranslatableString(
    en: 'Dispatch',
    ar: 'الإرسال',
    ur: 'ڈسپیچ',
    hi: 'डिस्पैच',
  );
  static const procurementArranging = TranslatableString(
    en: 'Procurement is arranging the items',
    ar: 'تقوم المشتريات بترتيب العناصر',
    ur: 'پروکیورمنٹ آئٹمز کا انتظام کر رہی ہے',
    hi: 'खरीद विभाग आइटम व्यवस्थित कर रहा है',
  );
  static const waitingForApproval = TranslatableString(
    en: 'Waiting for a Project Engineer approval',
    ar: 'بانتظار موافقة مهندس المشروع',
    ur: 'پراجیکٹ انجینئر کی منظوری کا انتظار ہے',
    hi: 'प्रोजेक्ट इंजीनियर की मंजूरी की प्रतीक्षा है',
  );
  static const readyForDispatch = TranslatableString(
    en: 'Ready for dispatch',
    ar: 'جاهز للإرسال',
    ur: 'ڈسپیچ کے لیے تیار',
    hi: 'डिस्पैच के लिए तैयार',
  );
  static const awaitingReceipt = TranslatableString(
    en: 'Awaiting site receipt',
    ar: 'بانتظار استلام الموقع',
    ur: 'سائٹ وصولی کا انتظار ہے',
    hi: 'साइट प्राप्ति की प्रतीक्षा है',
  );
  static const receiptCompleted = TranslatableString(
    en: 'Receipt review completed',
    ar: 'اكتملت مراجعة الاستلام',
    ur: 'وصولی کا جائزہ مکمل ہو گیا',
    hi: 'प्राप्ति समीक्षा पूर्ण हुई',
  );
  static const replacementDispatchRequired = TranslatableString(
    en: 'Replacement dispatch required',
    ar: 'مطلوب إرسال بديل',
    ur: 'متبادل ڈسپیچ درکار ہے',
    hi: 'प्रतिस्थापन डिस्पैच आवश्यक है',
  );
  static const closeReviewRequired = TranslatableString(
    en: 'Ready for Project Engineer closure',
    ar: 'جاهز للإغلاق بواسطة مهندس المشروع',
    ur: 'پروجیکٹ انجینئر کی بندش کے لیے تیار',
    hi: 'प्रोजेक्ट इंजीनियर द्वारा बंद करने के लिए तैयार',
  );
  static const closeRequest = TranslatableString(
    en: 'Close request',
    ar: 'إغلاق الطلب',
    ur: 'درخواست بند کریں',
    hi: 'अनुरोध बंद करें',
  );
  static const requestClosed = TranslatableString(
    en: 'Request closed',
    ar: 'تم إغلاق الطلب',
    ur: 'درخواست بند ہو گئی',
    hi: 'अनुरोध बंद हो गया',
  );
  static const requestDetails = TranslatableString(
    en: 'Request Details',
    ar: 'تفاصيل الطلب',
    ur: 'درخواست کی تفصیلات',
    hi: 'अनुरोध विवरण',
  );
  static const requestingRole = TranslatableString(
    en: 'Requesting role',
    ar: 'دور مقدم الطلب',
    ur: 'درخواست کنندہ کا کردار',
    hi: 'अनुरोधकर्ता भूमिका',
  );
  static const requested = TranslatableString(
    en: 'Requested',
    ar: 'المطلوب',
    ur: 'درخواست کردہ',
    hi: 'अनुरोधित',
  );
  static const lastUpdated = TranslatableString(
    en: 'Last updated',
    ar: 'آخر تحديث',
    ur: 'آخری اپڈیٹ',
    hi: 'अंतिम अपडेट',
  );
  static const controlledTableDescription = TranslatableString(
    en: 'Same column order as the Yorks paper form, without Remarks.',
    ar: 'نفس ترتيب الأعمدة في نموذج يوركس الورقي، من دون ملاحظات.',
    ur: 'یورکس کے کاغذی فارم جیسا ہی کالم آرڈر، بغیر ریمارکس کے۔',
    hi: 'Yorks पेपर फॉर्म जैसा ही कॉलम क्रम, Remarks के बिना।',
  );
  static const materialRequestForm = TranslatableString(
    en: 'MATERIAL REQUEST FORM',
    ar: 'طلب المواد',
    ur: 'میٹیریل ریکویسٹ',
    hi: 'सामग्री अनुरोध',
  );
  static const formalCompanyArabic = TranslatableString(
    en: 'Yorks AC. & Ref.',
    ar: 'يوركس للتكييف والتبريد',
    ur: 'یارکس اے سی اینڈ ریف',
    hi: 'यॉर्क्स एसी एंड रेफ.',
  );
  static const projectReference = TranslatableString(
    en: 'Project Ref.',
    ar: 'مرجع المشروع',
    ur: 'پراجیکٹ حوالہ',
    hi: 'प्रोजेक्ट संदर्भ',
  );
  static const projectName = TranslatableString(
    en: 'Project Name',
    ar: 'اسم المشروع',
    ur: 'پراجیکٹ نام',
    hi: 'प्रोजेक्ट नाम',
  );
  static const projectEngineers = TranslatableString(
    en: 'Project Engineers',
    ar: 'مهندسو المشروع',
    ur: 'پراجیکٹ انجینئرز',
    hi: 'प्रोजेक्ट इंजीनियर',
  );
  static const deliveryType = TranslatableString(
    en: 'Delivery Type',
    ar: 'نوع التسليم',
    ur: 'ڈیلیوری کی قسم',
    hi: 'डिलीवरी प्रकार',
  );
  static const buildingOther = TranslatableString(
    en: 'Building / Other',
    ar: 'المبنى / أخرى',
    ur: 'عمارت / دیگر',
    hi: 'भवन / अन्य',
  );
  static const requestedByEngineer = TranslatableString(
    en: 'Requested by (Site / Project Engineer)',
    ar: 'مطلوب من مهندس الموقع / المشروع',
    ur: 'سائٹ / پراجیکٹ انجینئر نے درخواست دی',
    hi: 'साइट / प्रोजेक्ट इंजीनियर द्वारा अनुरोधित',
  );
  static const approvedByEngineer = TranslatableString(
    en: 'Approved by (Project Engineer)',
    ar: 'معتمد من مهندس المشروع',
    ur: 'پراجیکٹ انجینئر نے منظور کیا',
    hi: 'प्रोजेक्ट इंजीनियर द्वारा स्वीकृत',
  );
  static const dispatchedByProcurement = TranslatableString(
    en: 'Ordered / Dispatched by (Procurement)',
    ar: 'تم الطلب / الإرسال بواسطة المشتريات',
    ur: 'پروکیورمنٹ نے آرڈر / ڈسپیچ کیا',
    hi: 'खरीद द्वारा आदेशित / डिस्पैच',
  );
  static const name = TranslatableString(
    en: 'Name',
    ar: 'الاسم',
    ur: 'نام',
    hi: 'नाम',
  );
  static const role = TranslatableString(
    en: 'Role',
    ar: 'الدور',
    ur: 'کردار',
    hi: 'भूमिका',
  );
  static const date = TranslatableString(
    en: 'Date',
    ar: 'التاريخ',
    ur: 'تاریخ',
    hi: 'दिनांक',
  );
  static const arrangementDescription = TranslatableString(
    en: 'Procurement records the available quantities and any exception before approval.',
    ar: 'تسجل المشتريات الكميات المتاحة وأي استثناء قبل الموافقة.',
    ur: 'پروکیورمنٹ منظوری سے پہلے دستیاب مقدار اور کسی بھی استثنا کو ریکارڈ کرتی ہے۔',
    hi: 'खरीद मंजूरी से पहले उपलब्ध मात्रा और किसी भी अपवाद को दर्ज करता है।',
  );
  static const notArrangedYet = TranslatableString(
    en: 'Not arranged yet',
    ar: 'لم يتم الترتيب بعد',
    ur: 'ابھی ترتیب نہیں دیا گیا',
    hi: 'अभी व्यवस्थित नहीं किया गया',
  );
  static const arrangementPendingDescription = TranslatableString(
    en: 'Procurement will choose the source, arrange available quantities and identify any item that cannot be provided.',
    ar: 'ستختار المشتريات المصدر وترتب الكميات المتاحة وتحدد أي بند لا يمكن توفيره.',
    ur: 'پروکیورمنٹ ذریعہ منتخب کرے گی، دستیاب مقدار ترتیب دے گی اور ناقابل فراہمی آئٹمز واضح کرے گی۔',
    hi: 'खरीद स्रोत चुनेगा, उपलब्ध मात्रा व्यवस्थित करेगा और अनुपलब्ध वस्तुओं को स्पष्ट करेगा।',
  );
  static const arrangementUnavailable = TranslatableString(
    en: 'Arrangement details are unavailable',
    ar: 'تفاصيل الترتيب غير متاحة',
    ur: 'ترتیب کی تفصیلات دستیاب نہیں ہیں',
    hi: 'व्यवस्था विवरण उपलब्ध नहीं है',
  );
  static const arrangementUnavailableDescription = TranslatableString(
    en: 'Refresh when connected to load the latest authorised arrangement.',
    ar: 'قم بالتحديث أثناء الاتصال لتحميل أحدث ترتيب مخوّل.',
    ur: 'تازہ مجاز ترتیب لوڈ کرنے کے لیے کنکشن کے ساتھ ریفریش کریں۔',
    hi: 'नवीनतम अधिकृत व्यवस्था लोड करने के लिए कनेक्ट होने पर रीफ्रेश करें।',
  );
  static const dispatchDescription = TranslatableString(
    en: 'Dispatch and site receipt remain part of this same material request.',
    ar: 'يبقى الإرسال واستلام الموقع جزءًا من طلب المواد نفسه.',
    ur: 'ڈسپیچ اور سائٹ وصولی اسی میٹیریل ریکویسٹ کا حصہ رہتے ہیں۔',
    hi: 'डिस्पैच और साइट प्राप्ति इसी सामग्री अनुरोध का हिस्सा रहते हैं।',
  );
  static const noDispatchYet = TranslatableString(
    en: 'No dispatch yet',
    ar: 'لا يوجد إرسال بعد',
    ur: 'ابھی کوئی ڈسپیچ نہیں',
    hi: 'अभी कोई डिस्पैच नहीं',
  );
  static const dispatchPendingDescription = TranslatableString(
    en: 'Procurement can dispatch after a Project Engineer approves the arrangement.',
    ar: 'يمكن للمشتريات الإرسال بعد موافقة مهندس المشروع على الترتيب.',
    ur: 'پروکیورمنٹ پراجیکٹ انجینئر کی منظوری کے بعد ڈسپیچ کر سکتی ہے۔',
    hi: 'प्रोजेक्ट इंजीनियर के व्यवस्था अनुमोदन के बाद खरीद डिस्पैच कर सकता है।',
  );
  static const dispatchReadyDescription = TranslatableString(
    en: 'Approved quantities can now be prepared for controlled dispatch.',
    ar: 'يمكن الآن تجهيز الكميات المعتمدة للإرسال المتحكم به.',
    ur: 'منظور شدہ مقدار اب کنٹرولڈ ڈسپیچ کے لیے تیار کی جا سکتی ہے۔',
    hi: 'स्वीकृत मात्रा अब नियंत्रित डिस्पैच के लिए तैयार की जा सकती है।',
  );
  static const returnsDescription = TranslatableString(
    en: 'Delivery Orders and material returns are linked to the original request.',
    ar: 'ترتبط أوامر التسليم ومرتجعات المواد بالطلب الأصلي.',
    ur: 'ڈیلیوری آرڈرز اور میٹیریل ریٹرنز اصل درخواست سے منسلک ہیں۔',
    hi: 'डिलीवरी ऑर्डर और सामग्री रिटर्न मूल अनुरोध से जुड़े हैं।',
  );
  static const noReturnedMaterial = TranslatableString(
    en: 'No returned material',
    ar: 'لا توجد مواد مرتجعة',
    ur: 'کوئی واپس شدہ میٹیریل نہیں',
    hi: 'कोई लौटाई गई सामग्री नहीं',
  );
  static const returnAfterReceipt = TranslatableString(
    en: 'An eligible received item can be returned from this request when it is no longer required.',
    ar: 'يمكن إرجاع بند مستلم مؤهل من هذا الطلب عند عدم الحاجة إليه.',
    ur: 'جب وصول شدہ میٹیریل کی ضرورت نہ رہے تو اسے اس درخواست سے واپس کیا جا سکتا ہے۔',
    hi: 'जब प्राप्त वस्तु की आवश्यकता न हो तो इसे इस अनुरोध से लौटाया जा सकता है।',
  );
  static const deliveryOrderAfterReceipt = TranslatableString(
    en: 'The committed dispatch is ready for its immutable Delivery Order.',
    ar: 'الإرسال المعتمد جاهز لأمر التسليم غير القابل للتعديل.',
    ur: 'تصدیق شدہ ڈسپیچ اپنے ناقابلِ ترمیم ڈیلیوری آرڈر کے لیے تیار ہے۔',
    hi: 'पुष्ट डिस्पैच अपने अपरिवर्तनीय डिलीवरी ऑर्डर के लिए तैयार है।',
  );
  static const controlledDocumentLoading = TranslatableString(
    en: 'Preparing the controlled document…',
    ar: 'جارٍ إعداد المستند المراقب…',
    ur: 'کنٹرولڈ دستاویز تیار کی جا رہی ہے…',
    hi: 'नियंत्रित दस्तावेज़ तैयार किया जा रहा है…',
  );
  static const controlledDocumentUnavailable = TranslatableString(
    en: 'The controlled document details are unavailable. Refresh and try again.',
    ar: 'تفاصيل المستند المراقب غير متاحة. حدّث الصفحة وحاول مرة أخرى.',
    ur: 'کنٹرولڈ دستاویز کی تفصیلات دستیاب نہیں ہیں۔ ریفریش کر کے دوبارہ کوشش کریں۔',
    hi: 'नियंत्रित दस्तावेज़ विवरण उपलब्ध नहीं हैं। रीफ़्रेश करके फिर प्रयास करें।',
  );
  static const item = TranslatableString(
    en: 'Item',
    ar: 'البند',
    ur: 'آئٹم',
    hi: 'आइटम',
  );
  static const warehouse = TranslatableString(
    en: 'Warehouse',
    ar: 'المستودع',
    ur: 'گودام',
    hi: 'गोदाम',
  );
  static const externalSupplier = TranslatableString(
    en: 'External supplier',
    ar: 'مورد خارجي',
    ur: 'بیرونی سپلائر',
    hi: 'बाहरी आपूर्तिकर्ता',
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
