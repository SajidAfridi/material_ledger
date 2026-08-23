import 'app_strings.dart';
import 'yorks_v1_domain_error.dart';
import 'yorks_v1_company_document_strings.dart';
import 'yorks_v1_material_request.dart';

/// Centralized bilingual-capable presentation copy for the Yorks V1 Material
/// Request slice. Domain and database layers use stable codes, never this copy.
abstract final class YorksV1MaterialRequestStrings {
  static const tryAgain = TranslatableString(
    en: 'Try again',
    ar: 'حاول مرة أخرى',
    ur: 'دوبارہ کوشش کریں',
    hi: 'फिर से प्रयास करें',
  );
  static const loadEarlierComments = TranslatableString(
    en: 'Load earlier comments',
    ar: 'تحميل التعليقات السابقة',
    ur: 'پچھلے تبصرے لوڈ کریں',
    hi: 'पहले की टिप्पणियां लोड करें',
  );
  static const savedToYourAccount = TranslatableString(
    en: 'Saved to your account',
    ar: 'تم الحفظ في حسابك',
    ur: 'آپ کے اکاؤنٹ میں محفوظ ہو گیا',
    hi: 'आपके खाते में सहेजा गया',
  );
  static const assignedTo = TranslatableString(
    en: 'Assigned to',
    ar: 'مسند إلى',
    ur: 'ذمہ دار',
    hi: 'इन्हें सौंपा गया',
  );
  static const unassigned = TranslatableString(
    en: 'Unassigned',
    ar: 'غير مسند',
    ur: 'غیر تفویض شدہ',
    hi: 'असाइन नहीं किया गया',
  );
  static const claimRequest = TranslatableString(
    en: 'Claim request',
    ar: 'تولي الطلب',
    ur: 'درخواست سنبھالیں',
    hi: 'अनुरोध लें',
  );
  static const reassign = TranslatableString(
    en: 'Reassign',
    ar: 'إعادة الإسناد',
    ur: 'دوبارہ تفویض کریں',
    hi: 'फिर से असाइन करें',
  );
  static const changesSinceReturn = TranslatableString(
    en: 'Changes made since this request was returned',
    ar: 'التغييرات منذ إعادة هذا الطلب',
    ur: 'درخواست واپس ہونے کے بعد کی تبدیلیاں',
    hi: 'अनुरोध लौटाए जाने के बाद किए गए बदलाव',
  );
  static const selectAssignee = TranslatableString(
    en: 'Select responsible person',
    ar: 'اختر الشخص المسؤول',
    ur: 'ذمہ دار شخص منتخب کریں',
    hi: 'जिम्मेदार व्यक्ति चुनें',
  );
  static const reassignmentReason = TranslatableString(
    en: 'Reason for reassignment',
    ar: 'سبب إعادة الإسناد',
    ur: 'دوبارہ تفویض کی وجہ',
    hi: 'फिर से असाइन करने का कारण',
  );
  static TranslatableString itemsAdded(int count) => TranslatableString(
    en: '$count ${count == 1 ? 'item' : 'items'} added',
    ar: 'تمت إضافة $count من البنود',
    ur: '$count آئٹمز شامل کیے گئے',
    hi: '$count आइटम जोड़े गए',
  );
  static TranslatableString itemsRemoved(int count) => TranslatableString(
    en: '$count ${count == 1 ? 'item' : 'items'} removed',
    ar: 'تمت إزالة $count من البنود',
    ur: '$count آئٹمز ہٹائے گئے',
    hi: '$count आइटम हटाए गए',
  );
  static TranslatableString quantitiesChanged(int count) => TranslatableString(
    en: '$count ${count == 1 ? 'quantity' : 'quantities'} changed',
    ar: 'تم تغيير $count من الكميات',
    ur: '$count مقداریں تبدیل ہوئیں',
    hi: '$count मात्राएं बदली गईं',
  );
  static const deliveryNoteUpdated = TranslatableString(
    en: 'Delivery note updated',
    ar: 'تم تحديث ملاحظة التسليم',
    ur: 'ڈیلیوری نوٹ اپ ڈیٹ ہوا',
    hi: 'डिलीवरी नोट अपडेट किया गया',
  );
  static const requestDetailsUpdated = TranslatableString(
    en: 'Request details updated',
    ar: 'تم تحديث تفاصيل الطلب',
    ur: 'درخواست کی تفصیلات اپ ڈیٹ ہوئیں',
    hi: 'अनुरोध विवरण अपडेट किए गए',
  );
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
  static const materialRequestCentre = TranslatableString(
    en: 'Material Request Centre',
    ar: 'مركز طلبات المواد',
    ur: 'میٹیریل ریکویسٹ سینٹر',
    hi: 'सामग्री अनुरोध केंद्र',
  );
  static const materialRequestCentreDescription = TranslatableString(
    en: 'Manage and track material requests across all authorized projects.',
    ar: 'إدارة وتتبع طلبات المواد عبر جميع المشاريع المصرح بها.',
    ur: 'تمام مجاز پراجیکٹس میں میٹیریل ریکویسٹس کا انتظام اور ٹریکنگ کریں۔',
    hi: 'सभी अधिकृत परियोजनाओं में सामग्री अनुरोधों का प्रबंधन और ट्रैक करें।',
  );
  static const totalRequests = TranslatableString(
    en: 'Total Requests',
    ar: 'إجمالي الطلبات',
    ur: 'کل درخواستیں',
    hi: 'कुल अनुरोध',
  );
  static const totalMaterialRequests = TranslatableString(
    en: 'Total Material Requests',
    ar: 'إجمالي طلبات المواد',
    ur: 'کل میٹیریل ریکویسٹس',
    hi: 'कुल सामग्री अनुरोध',
  );
  static const activeRequests = TranslatableString(
    en: 'Active Requests',
    ar: 'الطلبات النشطة',
    ur: 'فعال درخواستیں',
    hi: 'सक्रिय अनुरोध',
  );
  static const openMetric = TranslatableString(
    en: 'Open',
    ar: 'مفتوح',
    ur: 'کھلی درخواستیں',
    hi: 'खुले अनुरोध',
  );
  static const viewOpen = TranslatableString(
    en: 'View open',
    ar: 'عرض المفتوحة',
    ur: 'کھلی دیکھیں',
    hi: 'खुले देखें',
  );
  static const inProgressMetric = TranslatableString(
    en: 'In Progress',
    ar: 'قيد التنفيذ',
    ur: 'جاری',
    hi: 'प्रगति में',
  );
  static const viewInProgress = TranslatableString(
    en: 'View in progress',
    ar: 'عرض قيد التنفيذ',
    ur: 'جاری درخواستیں دیکھیں',
    hi: 'प्रगति में देखें',
  );
  static const awaitingApprovalMetric = TranslatableString(
    en: 'Awaiting Approval',
    ar: 'بانتظار الموافقة',
    ur: 'منظوری کا انتظار',
    hi: 'अनुमोदन की प्रतीक्षा',
  );
  static const procurementQueue = TranslatableString(
    en: 'Procurement',
    ar: 'المشتريات',
    ur: 'پروکیورمنٹ',
    hi: 'खरीद',
  );
  static const inArrangement = TranslatableString(
    en: 'In arrangement',
    ar: 'قيد الترتيب',
    ur: 'انتظام میں',
    hi: 'व्यवस्था में',
  );
  static const dispatchedMetric = TranslatableString(
    en: 'Dispatched',
    ar: 'تم الإرسال',
    ur: 'بھیجا گیا',
    hi: 'डिस्पैच किया गया',
  );
  static const onTheWay = TranslatableString(
    en: 'On the way',
    ar: 'في الطريق',
    ur: 'راستے میں',
    hi: 'रास्ते में',
  );
  static const receivedMetric = TranslatableString(
    en: 'Received',
    ar: 'تم الاستلام',
    ur: 'وصول شدہ',
    hi: 'प्राप्त',
  );
  static const atSiteOrWarehouse = TranslatableString(
    en: 'At site / warehouse',
    ar: 'في الموقع / المستودع',
    ur: 'سائٹ / گودام پر',
    hi: 'साइट / गोदाम में',
  );
  static const closedMetric = TranslatableString(
    en: 'Closed',
    ar: 'مغلق',
    ur: 'بند',
    hi: 'बंद',
  );
  static const completed = TranslatableString(
    en: 'Completed',
    ar: 'مكتمل',
    ur: 'مکمل',
    hi: 'पूर्ण',
  );
  static const projectFolders = TranslatableString(
    en: 'Project Folders',
    ar: 'مجلدات المشاريع',
    ur: 'پراجیکٹ فولڈرز',
    hi: 'परियोजना फ़ोल्डर',
  );
  static const projects = TranslatableString(
    en: 'Projects',
    ar: 'المشاريع',
    ur: 'پراجیکٹس',
    hi: 'परियोजनाएं',
  );
  static const allRequests = TranslatableString(
    en: 'All Requests',
    ar: 'كل الطلبات',
    ur: 'تمام درخواستیں',
    hi: 'सभी अनुरोध',
  );
  static const myMaterialRequests = TranslatableString(
    en: 'My Material Requests',
    ar: 'طلبات المواد الخاصة بي',
    ur: 'میری میٹیریل ریکویسٹس',
    hi: 'मेरे सामग्री अनुरोध',
  );
  static const assignedMaterialRequests = TranslatableString(
    en: 'Assigned Material Requests',
    ar: 'طلبات المواد المسندة',
    ur: 'تفویض شدہ میٹیریل ریکویسٹس',
    hi: 'सौंपे गए सामग्री अनुरोध',
  );
  static const savedDrafts = TranslatableString(
    en: 'Saved Drafts',
    ar: 'المسودات المحفوظة',
    ur: 'محفوظ شدہ ڈرافٹس',
    hi: 'सहेजे गए ड्राफ़्ट',
  );
  static const deleteDraft = TranslatableString(
    en: 'Delete draft',
    ar: 'حذف المسودة',
    ur: 'ڈرافٹ حذف کریں',
    hi: 'ड्राफ़्ट हटाएं',
  );
  static const deleteDraftBody = TranslatableString(
    en: 'This unfinished material request will be permanently removed from your private drafts.',
    ar: 'ستتم إزالة طلب المواد غير المكتمل نهائيًا من مسوداتك الخاصة.',
    ur: 'یہ نامکمل میٹیریل ریکویسٹ آپ کے نجی ڈرافٹس سے مستقل طور پر حذف ہو جائے گی۔',
    hi: 'यह अधूरा सामग्री अनुरोध आपके निजी ड्राफ़्ट से स्थायी रूप से हटा दिया जाएगा।',
  );
  static const draftDeleted = TranslatableString(
    en: 'Draft deleted',
    ar: 'تم حذف المسودة',
    ur: 'ڈرافٹ حذف ہو گیا',
    hi: 'ड्राफ़्ट हटा दिया गया',
  );
  static const draftDeleteFailed = TranslatableString(
    en: 'The draft could not be deleted. Please try again.',
    ar: 'تعذر حذف المسودة. يرجى المحاولة مرة أخرى.',
    ur: 'ڈرافٹ حذف نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    hi: 'ड्राफ्ट हटाया नहीं जा सका। कृपया फिर से प्रयास करें।',
  );
  static const attentionRequired = TranslatableString(
    en: 'Attention Required',
    ar: 'يتطلب اهتمامًا',
    ur: 'توجہ درکار',
    hi: 'ध्यान आवश्यक',
  );
  static const requiresActionOnly = TranslatableString(
    en: 'Show only requests requiring action',
    ar: 'عرض الطلبات التي تتطلب إجراءً فقط',
    ur: 'صرف کارروائی کی ضرورت والی درخواستیں دکھائیں',
    hi: 'केवल कार्रवाई वाले अनुरोध दिखाएं',
  );
  static const closedArchive = TranslatableString(
    en: 'Closed Archive',
    ar: 'أرشيف الطلبات المغلقة',
    ur: 'بند شدہ آرکائیو',
    hi: 'बंद संग्रह',
  );
  static const searchRequests = TranslatableString(
    en: 'Search projects, requests, items…',
    ar: 'ابحث في المشاريع والطلبات والمواد…',
    ur: 'پراجیکٹس، درخواستیں، آئٹمز تلاش کریں…',
    hi: 'परियोजनाएं, अनुरोध, आइटम खोजें…',
  );
  static const searchProjects = TranslatableString(
    en: 'Search projects…',
    ar: 'ابحث في المشاريع…',
    ur: 'پراجیکٹس تلاش کریں…',
    hi: 'परियोजनाएं खोजें…',
  );
  static const sortBy = TranslatableString(
    en: 'Sort by',
    ar: 'ترتيب حسب',
    ur: 'ترتیب',
    hi: 'इसके अनुसार क्रमबद्ध करें',
  );
  static const latestActivity = TranslatableString(
    en: 'Latest Activity',
    ar: 'أحدث نشاط',
    ur: 'تازہ ترین سرگرمی',
    hi: 'नवीनतम गतिविधि',
  );
  static const oldestActivity = TranslatableString(
    en: 'Oldest Activity',
    ar: 'أقدم نشاط',
    ur: 'قدیم ترین سرگرمی',
    hi: 'सबसे पुरानी गतिविधि',
  );
  static const filters = TranslatableString(
    en: 'Filters',
    ar: 'عوامل التصفية',
    ur: 'فلٹرز',
    hi: 'फ़िल्टर',
  );
  static const clearAll = TranslatableString(
    en: 'Clear all',
    ar: 'مسح الكل',
    ur: 'سب صاف کریں',
    hi: 'सभी साफ़ करें',
  );
  static const allStatuses = TranslatableString(
    en: 'All statuses',
    ar: 'كل الحالات',
    ur: 'تمام اسٹیٹس',
    hi: 'सभी स्थितियां',
  );
  static const allProjects = TranslatableString(
    en: 'All projects',
    ar: 'كل المشاريع',
    ur: 'تمام پراجیکٹس',
    hi: 'सभी परियोजनाएं',
  );
  static const allBuildings = TranslatableString(
    en: 'All buildings',
    ar: 'كل المباني',
    ur: 'تمام عمارتیں',
    hi: 'सभी भवन',
  );
  static const allUsers = TranslatableString(
    en: 'All users',
    ar: 'كل المستخدمين',
    ur: 'تمام صارفین',
    hi: 'सभी उपयोगकर्ता',
  );
  static const dateRange = TranslatableString(
    en: 'Date range',
    ar: 'النطاق الزمني',
    ur: 'تاریخ کی حد',
    hi: 'तारीख सीमा',
  );
  static const allTime = TranslatableString(
    en: 'All time',
    ar: 'كل الوقت',
    ur: 'تمام وقت',
    hi: 'हर समय',
  );
  static const last7Days = TranslatableString(
    en: 'Last 7 days',
    ar: 'آخر 7 أيام',
    ur: 'گزشتہ 7 دن',
    hi: 'पिछले 7 दिन',
  );
  static const last30Days = TranslatableString(
    en: 'Last 30 days',
    ar: 'آخر 30 يومًا',
    ur: 'گزشتہ 30 دن',
    hi: 'पिछले 30 दिन',
  );
  static const applyFilters = TranslatableString(
    en: 'Apply filters',
    ar: 'تطبيق عوامل التصفية',
    ur: 'فلٹرز لاگو کریں',
    hi: 'फ़िल्टर लागू करें',
  );
  static const latestRequest = TranslatableString(
    en: 'Latest Request',
    ar: 'أحدث طلب',
    ur: 'تازہ ترین درخواست',
    hi: 'नवीनतम अनुरोध',
  );
  static const currentWorkflowAction = TranslatableString(
    en: 'Current workflow action',
    ar: 'إجراء سير العمل الحالي',
    ur: 'موجودہ ورک فلو ایکشن',
    hi: 'वर्तमान कार्यप्रवाह क्रिया',
  );
  static const scopes = TranslatableString(
    en: 'Scopes',
    ar: 'النطاقات',
    ur: 'اسکوپس',
    hi: 'दायरे',
  );
  static const active = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال',
    hi: 'सक्रिय',
  );
  static const updated = TranslatableString(
    en: 'Updated',
    ar: 'تم التحديث',
    ur: 'اپ ڈیٹ',
    hi: 'अपडेट किया गया',
  );
  static const noMatchingRequests = TranslatableString(
    en: 'No requests match these filters.',
    ar: 'لا توجد طلبات تطابق عوامل التصفية هذه.',
    ur: 'ان فلٹرز سے کوئی درخواست مطابقت نہیں رکھتی۔',
    hi: 'इन फ़िल्टरों से कोई अनुरोध मेल नहीं खाता।',
  );
  static const gridView = TranslatableString(
    en: 'Grid view',
    ar: 'عرض شبكي',
    ur: 'گرڈ ویو',
    hi: 'ग्रिड दृश्य',
  );
  static const listView = TranslatableString(
    en: 'List view',
    ar: 'عرض قائمة',
    ur: 'فہرست ویو',
    hi: 'सूची दृश्य',
  );
  static TranslatableString itemsCount(int count) => TranslatableString(
    en: '$count items',
    ar: '$count بنود',
    ur: '$count آئٹمز',
    hi: '$count आइटम',
  );
  static TranslatableString scopesCount(int count) => TranslatableString(
    en: '$count scopes',
    ar: '$count نطاقات',
    ur: '$count اسکوپس',
    hi: '$count दायरे',
  );
  static const workflowDescription = TranslatableString(
    en: 'Created → Engineering approval → Procurement arrangement → Dispatch → Site receipt → Completion.',
    ar: 'الإنشاء ← موافقة الهندسة ← ترتيب المشتريات ← الإرسال ← استلام الموقع ← الإكمال.',
    ur: 'تخلیق → انجینئرنگ منظوری → پروکیورمنٹ انتظام → ڈسپیچ → سائٹ وصولی → تکمیل۔',
    hi: 'निर्माण → इंजीनियरिंग अनुमोदन → खरीद व्यवस्था → डिस्पैच → साइट प्राप्ति → पूर्णता।',
  );
  static TranslatableString stageOfSeven(int stage) => TranslatableString(
    en: 'Stage $stage of 7',
    ar: 'المرحلة $stage من 7',
    ur: '7 میں سے مرحلہ $stage',
    hi: '7 में से चरण $stage',
  );
  static const requestCreated = TranslatableString(
    en: 'Created',
    ar: 'تم الإنشاء',
    ur: 'تخلیق شدہ',
    hi: 'बनाया गया',
  );
  static const engineeringApproval = TranslatableString(
    en: 'Engineering Approval',
    ar: 'موافقة الهندسة',
    ur: 'انجینئرنگ منظوری',
    hi: 'इंजीनियरिंग अनुमोदन',
  );
  static const engineeringApprovalShort = TranslatableString(
    en: 'PE Approval',
    ar: 'موافقة المهندس',
    ur: 'پی ای منظوری',
    hi: 'पीई अनुमोदन',
  );
  static const procurementArrangement = TranslatableString(
    en: 'Procurement Arrangement',
    ar: 'ترتيب المشتريات',
    ur: 'پروکیورمنٹ انتظام',
    hi: 'खरीद व्यवस्था',
  );
  static const procurementArrangementShort = TranslatableString(
    en: 'Arrange',
    ar: 'الترتيب',
    ur: 'انتظام',
    hi: 'व्यवस्था',
  );
  static const readyForDeliveryStage = TranslatableString(
    en: 'Ready for Delivery',
    ar: 'جاهز للتسليم',
    ur: 'ڈیلیوری کے لیے تیار',
    hi: 'डिलीवरी के लिए तैयार',
  );
  static const readyForDeliveryShort = TranslatableString(
    en: 'Ready',
    ar: 'جاهز',
    ur: 'تیار',
    hi: 'तैयार',
  );
  static const receivedStage = TranslatableString(
    en: 'Received',
    ar: 'تم الاستلام',
    ur: 'وصول شدہ',
    hi: 'प्राप्त',
  );
  static const completedStage = TranslatableString(
    en: 'Completed',
    ar: 'مكتمل',
    ur: 'مکمل',
    hi: 'पूर्ण',
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
    en: 'S.No',
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
  static const awaitingRequestApproval = TranslatableString(
    en: 'Awaiting Engineering approval',
    ar: 'بانتظار موافقة الهندسة',
    ur: 'انجینئرنگ کی منظوری کا انتظار',
    hi: 'इंजीनियरिंग अनुमोदन की प्रतीक्षा',
  );
  static const changesRequested = TranslatableString(
    en: 'Changes requested',
    ar: 'التعديلات مطلوبة',
    ur: 'تبدیلیاں درکار ہیں',
    hi: 'बदलाव आवश्यक हैं',
  );
  static const approvedForArrangement = TranslatableString(
    en: 'Approved for Procurement',
    ar: 'معتمد للمشتريات',
    ur: 'پروکیورمنٹ کے لیے منظور شدہ',
    hi: 'खरीद व्यवस्था के लिए स्वीकृत',
  );
  static const editRequest = TranslatableString(
    en: 'Edit request',
    ar: 'تحرير الطلب',
    ur: 'درخواست میں ترمیم کریں',
    hi: 'अनुरोध संपादित करें',
  );
  static const approveForProcurement = TranslatableString(
    en: 'Approve for Procurement',
    ar: 'الموافقة للمشتريات',
    ur: 'پروکیورمنٹ کے لیے منظور کریں',
    hi: 'खरीद व्यवस्था के लिए स्वीकृत करें',
  );
  static const returnForChanges = TranslatableString(
    en: 'Return for changes',
    ar: 'إعادة للتعديل',
    ur: 'تبدیلیوں کے لیے واپس کریں',
    hi: 'बदलाव के लिए लौटाएँ',
  );
  static const requestApprovalPrompt = TranslatableString(
    en: 'Approve this Engineering request before Procurement arranges stock or supplier sourcing.',
    ar: 'اعتمد طلب الهندسة هذا قبل أن ترتب المشتريات المخزون أو التوريد.',
    ur: 'پروکیورمنٹ کے اسٹاک یا سپلائر انتظام سے پہلے اس انجینئرنگ درخواست کو منظور کریں۔',
    hi: 'खरीद विभाग द्वारा स्टॉक या आपूर्तिकर्ता व्यवस्था से पहले इस इंजीनियरिंग अनुरोध को स्वीकृत करें।',
  );
  static const requestUpdatedForApproval = TranslatableString(
    en: 'Changes saved and sent for Engineering approval.',
    ar: 'تم حفظ التعديلات وإرسالها للموافقة الهندسية.',
    ur: 'تبدیلیاں محفوظ کر کے انجینئرنگ منظوری کے لیے بھیج دی گئی ہیں۔',
    hi: 'बदलाव सहेजकर इंजीनियरिंग अनुमोदन के लिए भेज दिए गए हैं।',
  );
  static const discussion = TranslatableString(
    en: 'Request Discussion',
    ar: 'مناقشة الطلب',
    ur: 'درخواست پر گفتگو',
    hi: 'अनुरोध चर्चा',
  );
  static const addComment = TranslatableString(
    en: 'Add Comment',
    ar: 'إضافة تعليق',
    ur: 'تبصرہ شامل کریں',
    hi: 'टिप्पणी जोड़ें',
  );
  static const discussionDescription = TranslatableString(
    en: 'Comments stay with this request through every stage. Mention an authorized teammate to notify them.',
    ar: 'تبقى التعليقات مع هذا الطلب في جميع المراحل. اذكر زميلاً مخولاً لإشعاره.',
    ur: 'تبصرے ہر مرحلے میں اس درخواست کے ساتھ رہتے ہیں۔ اطلاع کے لیے مجاز ساتھی کا ذکر کریں۔',
    hi: 'टिप्पणियाँ हर चरण में इस अनुरोध के साथ रहती हैं। सूचना के लिए अधिकृत साथी का उल्लेख करें।',
  );
  static const writeComment = TranslatableString(
    en: 'Write a comment',
    ar: 'اكتب تعليقًا',
    ur: 'تبصرہ لکھیں',
    hi: 'टिप्पणी लिखें',
  );
  static const commentComposerHint = TranslatableString(
    en: 'Write a comment and mention users…',
    ar: 'اكتب تعليقًا واذكر المستخدمين باستخدام @',
    ur: '@ کے ساتھ تبصرہ لکھیں اور صارفین کا ذکر کریں',
    hi: 'टिप्पणी लिखें और @ से उपयोगकर्ताओं का उल्लेख करें',
  );
  static const saveDraftToDiscuss = TranslatableString(
    en: 'Save this draft to start the request discussion.',
    ar: 'احفظ هذه المسودة لبدء مناقشة الطلب.',
    ur: 'درخواست پر گفتگو شروع کرنے کے لیے یہ ڈرافٹ محفوظ کریں۔',
    hi: 'अनुरोध चर्चा शुरू करने के लिए इस ड्राफ्ट को सहेजें।',
  );
  static const mentionNoMatches = TranslatableString(
    en: 'No authorized teammates match this mention.',
    ar: 'لا يوجد زملاء مخولون يطابقون هذا الذكر.',
    ur: 'اس ذکر سے کوئی مجاز ساتھی مطابقت نہیں رکھتا۔',
    hi: 'इस उल्लेख से कोई अधिकृत साथी मेल नहीं खाता।',
  );
  static const mentionTeammates = TranslatableString(
    en: 'Mention teammates',
    ar: 'ذكر الزملاء',
    ur: 'ساتھیوں کا ذکر کریں',
    hi: 'साथियों का उल्लेख करें',
  );
  static const postComment = TranslatableString(
    en: 'Post comment',
    ar: 'نشر التعليق',
    ur: 'تبصرہ پوسٹ کریں',
    hi: 'टिप्पणी पोस्ट करें',
  );
  static const noComments = TranslatableString(
    en: 'No comments yet',
    ar: 'لا توجد تعليقات بعد',
    ur: 'ابھی کوئی تبصرہ نہیں',
    hi: 'अभी कोई टिप्पणी नहीं है',
  );
  static const startDiscussion = TranslatableString(
    en: 'Start the discussion by adding a comment.',
    ar: 'ابدأ المناقشة بإضافة تعليق.',
    ur: 'تبصرہ شامل کرکے گفتگو شروع کریں۔',
    hi: 'टिप्पणी जोड़कर चर्चा शुरू करें।',
  );
  static const commentAttachmentsUnavailable = TranslatableString(
    en: 'Comment attachments are not available.',
    ar: 'مرفقات التعليقات غير متاحة.',
    ur: 'تبصرے کے منسلکات دستیاب نہیں ہیں۔',
    hi: 'टिप्पणी अटैचमेंट उपलब्ध नहीं हैं।',
  );
  static const searchInventory = TranslatableString(
    en: 'Search BOQ and inventory',
    ar: 'البحث في جدول الكميات والمخزون',
    ur: 'BOQ اور انوینٹری تلاش کریں',
    hi: 'बीओक्यू और इन्वेंटरी खोजें',
  );
  static const selectedScopeBoq = TranslatableString(
    en: 'Selected scope BOQ',
    ar: 'جدول كميات النطاق المحدد',
    ur: 'منتخب دائرہ BOQ',
    hi: 'चयनित स्कोप बीओक्यू',
  );
  static const projectBoq = TranslatableString(
    en: 'Project BOQ',
    ar: 'جدول كميات المشروع',
    ur: 'پراجیکٹ BOQ',
    hi: 'प्रोजेक्ट बीओक्यू',
  );
  static const inventoryCatalogue = TranslatableString(
    en: 'Inventory catalogue',
    ar: 'دليل المخزون',
    ur: 'انوینٹری کیٹلاگ',
    hi: 'इन्वेंटरी कैटलॉग',
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
    en: 'Type an item description to search this scope BOQ, the project BOQ, then inventory—or enter a custom item.',
    ar: 'اكتب وصف الصنف للبحث في جدول كميات هذا النطاق ثم المشروع ثم المخزون، أو أدخل صنفًا مخصصًا.',
    ur: 'اس دائرے کے BOQ، پھر پراجیکٹ BOQ اور پھر انوینٹری میں تلاش کے لیے تفصیل لکھیں، یا کسٹم آئٹم درج کریں۔',
    hi: 'इस स्कोप के बीओक्यू, फिर प्रोजेक्ट बीओक्यू और फिर इन्वेंटरी में खोजने के लिए विवरण लिखें—या कस्टम आइटम दर्ज करें।',
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
    en: 'Your request has been submitted for Engineering approval.',
    ar: 'تم إرسال طلبك للموافقة الهندسية.',
    ur: 'آپ کی درخواست انجینئرنگ منظوری کے لیے جمع ہو گئی ہے۔',
    hi: 'आपका अनुरोध इंजीनियरिंग अनुमोदन के लिए जमा हो गया है।',
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
  static const leaveDraftTitle = TranslatableString(
    en: 'Save this material request?',
    ar: 'هل تريد حفظ طلب المواد هذا؟',
    ur: 'کیا یہ مواد کی درخواست محفوظ کرنی ہے؟',
    hi: 'क्या यह सामग्री अनुरोध सहेजना है?',
  );
  static const leaveDraftBody = TranslatableString(
    en: 'You have changes that are not in your last saved draft. Save them to continue later, or discard them and go back.',
    ar: 'لديك تغييرات غير موجودة في آخر مسودة محفوظة. احفظها للمتابعة لاحقًا، أو تجاهلها وارجع.',
    ur: 'آپ کی کچھ تبدیلیاں آخری محفوظ شدہ مسودے میں نہیں ہیں۔ بعد میں جاری رکھنے کے لیے انہیں محفوظ کریں، یا رد کر کے واپس جائیں۔',
    hi: 'आपके कुछ बदलाव अंतिम सहेजे गए ड्राफ़्ट में नहीं हैं। बाद में जारी रखने के लिए उन्हें सहेजें, या छोड़कर वापस जाएँ।',
  );
  static const draftRecoveryAssurance = TranslatableString(
    en: 'Local recovery stays private until you submit for Engineering approval.',
    ar: 'يبقى الاسترداد المحلي خاصًا حتى ترسل الطلب للموافقة الهندسية.',
    ur: 'مقامی ریکوری انجینئرنگ منظوری کے لیے جمع کرانے تک نجی رہتی ہے۔',
    hi: 'स्थानीय रिकवरी इंजीनियरिंग अनुमोदन के लिए जमा करने तक निजी रहती है।',
  );
  static const saveDraftAndLeave = TranslatableString(
    en: 'Save draft & leave',
    ar: 'حفظ المسودة والمغادرة',
    ur: 'مسودہ محفوظ کریں اور جائیں',
    hi: 'ड्राफ़्ट सहेजें और जाएँ',
  );
  static const discardChangesAndLeave = TranslatableString(
    en: 'Discard changes & leave',
    ar: 'تجاهل التغييرات والمغادرة',
    ur: 'تبدیلیاں رد کریں اور جائیں',
    hi: 'बदलाव छोड़ें और जाएँ',
  );
  static const draftExitSaveFailed = TranslatableString(
    en: 'The draft could not be saved. Your editor is still open—check your connection and try again.',
    ar: 'تعذر حفظ المسودة. لا يزال المحرر مفتوحًا—تحقق من الاتصال وحاول مرة أخرى.',
    ur: 'مسودہ محفوظ نہیں ہو سکا۔ ایڈیٹر اب بھی کھلا ہے—کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    hi: 'ड्राफ़्ट सहेजा नहीं जा सका। संपादक अभी खुला है—कनेक्शन जाँचें और फिर प्रयास करें।',
  );
  static const draftExitDiscardFailed = TranslatableString(
    en: 'The changes could not be discarded safely. Nothing was closed; try again.',
    ar: 'تعذر تجاهل التغييرات بأمان. لم يتم إغلاق أي شيء؛ حاول مرة أخرى.',
    ur: 'تبدیلیاں محفوظ طریقے سے رد نہیں ہو سکیں۔ کچھ بند نہیں ہوا؛ دوبارہ کوشش کریں۔',
    hi: 'बदलाव सुरक्षित रूप से नहीं छोड़े जा सके। कुछ भी बंद नहीं हुआ; फिर प्रयास करें।',
  );
  static const submitToProcurement = TranslatableString(
    en: 'Submit for Engineering approval',
    ar: 'إرسال للموافقة الهندسية',
    ur: 'انجینئرنگ منظوری کے لیے جمع کرائیں',
    hi: 'इंजीनियरिंग अनुमोदन के लिए जमा करें',
  );
  static const submitted = TranslatableString(
    en: 'Submitted',
    ar: 'تم الإرسال',
    ur: 'جمع کرایا گیا',
    hi: 'जमा किया गया',
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
  static const createReplacementRequest = TranslatableString(
    en: 'Create replacement request',
    ar: 'إنشاء طلب بديل',
    ur: 'متبادل درخواست بنائیں',
    hi: 'प्रतिस्थापन अनुरोध बनाएं',
  );
  static const replacementRequestHelp = TranslatableString(
    en: 'Copy every unavailable item into a new private draft. The cancelled request and its history stay unchanged.',
    ar: 'انسخ كل عنصر غير متاح إلى مسودة خاصة جديدة. يبقى الطلب الملغى وسجله دون تغيير.',
    ur: 'ہر غیر دستیاب آئٹم کو نئی نجی مسودہ درخواست میں نقل کریں۔ منسوخ درخواست اور اس کی تاریخ تبدیل نہیں ہوگی۔',
    hi: 'हर अनुपलब्ध आइटम को नए निजी ड्राफ़्ट में कॉपी करें। रद्द अनुरोध और उसका इतिहास नहीं बदलेगा।',
  );
  static const replacementDraftCreated = TranslatableString(
    en: 'Replacement draft created',
    ar: 'تم إنشاء المسودة البديلة',
    ur: 'متبادل مسودہ بنا دیا گیا',
    hi: 'प्रतिस्थापन ड्राफ़्ट बनाया गया',
  );
  static const openReplacementRequest = TranslatableString(
    en: 'Open replacement request',
    ar: 'فتح الطلب البديل',
    ur: 'متبادل درخواست کھولیں',
    hi: 'प्रतिस्थापन अनुरोध खोलें',
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
    en: 'One clear lifecycle from creation to completion.',
    ar: 'دورة عمل واضحة واحدة من الإنشاء إلى الإكمال.',
    ur: 'تخلیق سے تکمیل تک ایک واضح لائف سائیکل۔',
    hi: 'निर्माण से पूर्णता तक एक स्पष्ट जीवनचक्र।',
  );
  static const request = TranslatableString(
    en: 'Request',
    ar: 'الطلب',
    ur: 'درخواست',
    hi: 'अनुरोध',
  );
  static const procurement = TranslatableString(
    en: 'Procurement by',
    ar: 'بواسطة المشتريات',
    ur: 'پروکیورمنٹ کی طرف سے',
    hi: 'खरीद द्वारा',
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
  static const controlledDocumentDescription = TranslatableString(
    en: 'Open the formal preview used for PDF and print.',
    ar: 'افتح المعاينة الرسمية المستخدمة لملف PDF والطباعة.',
    ur: 'PDF اور پرنٹ کے لیے رسمی پیش نظارہ کھولیں۔',
    hi: 'PDF और प्रिंट के लिए औपचारिक पूर्वावलोकन खोलें।',
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
  static const approvedBy = TranslatableString(
    en: 'Approved by',
    ar: 'معتمد من',
    ur: 'منظور کرنے والا',
    hi: 'अनुमोदित करने वाला',
  );
  static const dispatchedByProcurement = TranslatableString(
    en: 'Ordered / Dispatched by (Procurement)',
    ar: 'تم الطلب / الإرسال بواسطة المشتريات',
    ur: 'پروکیورمنٹ نے آرڈر / ڈسپیچ کیا',
    hi: 'खरीद द्वारा आदेशित / डिस्पैच',
  );
  static const orderedDispatched = TranslatableString(
    en: 'Ordered / Dispatched by',
    ar: 'تم الطلب / الإرسال بواسطة',
    ur: 'آرڈر / ڈسپیچ کرنے والا',
    hi: 'आदेश / डिस्पैच करने वाला',
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
    en: 'Procurement can dispatch after the approved request arrangement is saved.',
    ar: 'يمكن للمشتريات الإرسال بعد حفظ ترتيب الطلب المعتمد.',
    ur: 'منظور شدہ درخواست کا انتظام محفوظ ہونے کے بعد پروکیورمنٹ ڈسپیچ کر سکتی ہے۔',
    hi: 'स्वीकृत अनुरोध की व्यवस्था सहेजे जाने के बाद खरीद विभाग डिस्पैच कर सकता है।',
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
  YorksV1MaterialRequestState.awaitingRequestApproval =>
    YorksV1MaterialRequestStrings.awaitingRequestApproval,
  YorksV1MaterialRequestState.changesRequested =>
    YorksV1MaterialRequestStrings.changesRequested,
  YorksV1MaterialRequestState.approvedForArrangement =>
    YorksV1MaterialRequestStrings.approvedForArrangement,
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
