import 'app_strings.dart';
import 'yorks_v1_domain_error.dart';
import 'yorks_v1_project.dart';

/// Centralized, bilingual-capable copy for the Yorks V1 R35 Projects slice.
///
/// The workflow/domain layers intentionally expose stable codes only. Widgets
/// resolve their visible copy through this catalogue so the effective R35 UI
/// never turns repository errors or prototype text into user-facing strings.
abstract final class YorksV1ProjectStrings {
  static const projects = TranslatableString(
    en: 'Projects',
    ar: 'المشاريع',
    ur: 'پراجیکٹس',
    hi: 'परियोजनाएँ',
  );
  static const projectCreationEyebrow = TranslatableString(
    en: 'Projects',
    ar: 'المشاريع',
    ur: 'پراجیکٹس',
    hi: 'परियोजनाएँ',
  );
  static const createProject = TranslatableString(
    en: 'Create project',
    ar: 'إنشاء مشروع',
    ur: 'پراجیکٹ بنائیں',
    hi: 'परियोजना बनाएँ',
  );
  static const createProjectDescription = TranslatableString(
    en: 'A controlled five-step setup that can be completed without entering materials.',
    ar: 'قم بإعداد المشروع والوصول والمباني، ثم راجع السجل المتصل قبل إنشائه.',
    ur: 'پراجیکٹ، رسائی اور عمارتیں ترتیب دیں، پھر بنانے سے پہلے منسلک ریکارڈ کا جائزہ لیں۔',
    hi: 'परियोजना, पहुँच और भवन तैयार करें, फिर बनाने से पहले जुड़े रिकॉर्ड की समीक्षा करें।',
  );
  static const projectSetup = TranslatableString(
    en: 'Project setup',
    ar: 'إعداد المشروع',
    ur: 'پراجیکٹ سیٹ اپ',
    hi: 'प्रोजेक्ट सेटअप',
  );
  static const projectSetupDescription = TranslatableString(
    en: 'Add the project information and project team. Project Engineers can later add, replace or remove Site Engineer access.',
    ar: 'أضف معلومات المشروع وفريقه. يمكن لمهندسي المشروع لاحقاً إضافة أو استبدال أو إزالة وصول مهندسي الموقع.',
    ur: 'پراجیکٹ کی معلومات اور ٹیم شامل کریں۔ پراجیکٹ انجینئر بعد میں سائٹ انجینئر رسائی شامل، تبدیل یا ختم کر سکتے ہیں۔',
    hi: 'प्रोजेक्ट जानकारी और टीम जोड़ें। प्रोजेक्ट इंजीनियर बाद में साइट इंजीनियर पहुंच जोड़, बदल या हटा सकते हैं।',
  );
  static const stepSaved = TranslatableString(
    en: 'Saved just now',
    ar: 'تم الحفظ الآن',
    ur: 'ابھی محفوظ ہوا',
    hi: 'अभी सहेजा गया',
  );
  static const stepOf = TranslatableString(
    en: 'Step {current} of {total}',
    ar: 'الخطوة {current} من {total}',
    ur: 'مرحلہ {current} از {total}',
    hi: 'चरण {current} / {total}',
  );
  static const draftSaved = TranslatableString(
    en: 'Draft saved on this device',
    ar: 'تم حفظ المسودة على هذا الجهاز',
    ur: 'ڈرافٹ اس ڈیوائس پر محفوظ ہو گیا',
    hi: 'ड्राफ़्ट इस डिवाइस पर सहेजा गया',
  );
  static const saveDraft = TranslatableString(
    en: 'Save draft',
    ar: 'حفظ المسودة',
    ur: 'ڈرافٹ محفوظ کریں',
    hi: 'ड्राफ्ट सहेजें',
  );
  static const connectedCreation = TranslatableString(
    en: 'Connected creation',
    ar: 'إنشاء متصل',
    ur: 'منسلک تخلیق',
    hi: 'कनेक्टेड निर्माण',
  );
  static const connectedCreationDescription = TranslatableString(
    en: 'Creating a project needs a connection. The server creates its Common scope, team history and BOQ groups together.',
    ar: 'يتطلب إنشاء المشروع اتصالاً. ينشئ الخادم نطاقه المشترك وسجل الفريق ومجموعات جدول الكميات معاً.',
    ur: 'پراجیکٹ بنانے کے لیے کنکشن ضروری ہے۔ سرور اس کا مشترک دائرہ، ٹیم ہسٹری اور BOQ گروپس ایک ساتھ بناتا ہے۔',
    hi: 'परियोजना बनाने के लिए कनेक्शन चाहिए। सर्वर उसका साझा दायरा, टीम इतिहास और BOQ समूह एक साथ बनाता है।',
  );
  static const reviewBeforeCreate = TranslatableString(
    en: 'Review before creating',
    ar: 'راجع قبل الإنشاء',
    ur: 'بنانے سے پہلے جائزہ لیں',
    hi: 'बनाने से पहले समीक्षा करें',
  );
  static const readyToCreateWorkspace = TranslatableString(
    en: 'Ready to create the project workspace',
    ar: 'المشروع جاهز لإنشاء مساحة العمل',
    ur: 'پراجیکٹ ورک اسپیس بنانے کے لیے تیار ہے',
    hi: 'प्रोजेक्ट कार्यक्षेत्र बनाने के लिए तैयार',
  );
  static const materialsNotRequiredAtCreation = TranslatableString(
    en: 'Material lines are not required during project creation. The project opens with BOQ, Material Requests and Documents ready to use.',
    ar: 'لا تُطلب أسطر المواد أثناء إنشاء المشروع. يفتح المشروع مع جدول الكميات وطلبات المواد والمستندات جاهزة للاستخدام.',
    ur: 'پراجیکٹ بناتے وقت مٹیریل لائنز ضروری نہیں۔ پراجیکٹ BOQ، مٹیریل ریکوئسٹس اور دستاویزات کے ساتھ استعمال کے لیے کھلے گا۔',
    hi: 'परियोजना निर्माण के दौरान सामग्री पंक्तियाँ आवश्यक नहीं हैं। परियोजना BOQ, सामग्री अनुरोध और दस्तावेज़ों के साथ उपयोग के लिए खुलेगी।',
  );
  static const accessAndBuildings = TranslatableString(
    en: 'Access & Buildings',
    ar: 'الوصول والمباني',
    ur: 'رسائی اور عمارتیں',
    hi: 'पहुँच और भवन',
  );
  static const notProvided = TranslatableString(
    en: 'Not provided',
    ar: 'غير مقدم',
    ur: 'فراہم نہیں کیا گیا',
    hi: 'प्रदान नहीं किया गया',
  );
  static const projectCreated = TranslatableString(
    en: 'Project created',
    ar: 'تم إنشاء المشروع',
    ur: 'پراجیکٹ بن گیا',
    hi: 'परियोजना बन गई',
  );
  static const projectCreatedDescription = TranslatableString(
    en: 'The server created the project, its Common scope, buildings, team history and default BOQ groups.',
    ar: 'أنشأ الخادم المشروع ونطاقه المشترك والمباني وسجل الفريق ومجموعات جدول الكميات الافتراضية.',
    ur: 'سرور نے پراجیکٹ، اس کا مشترک دائرہ، عمارتیں، ٹیم ہسٹری اور ڈیفالٹ BOQ گروپس بنائے۔',
    hi: 'सर्वर ने परियोजना, उसका साझा दायरा, भवन, टीम इतिहास और डिफ़ॉल्ट BOQ समूह बनाए।',
  );
  static const creationFailed = TranslatableString(
    en: 'Project could not be created',
    ar: 'تعذر إنشاء المشروع',
    ur: 'پراجیکٹ نہیں بنایا جا سکا',
    hi: 'परियोजना नहीं बनाई जा सकी',
  );
  static const createAndView = TranslatableString(
    en: 'Create project',
    ar: 'إنشاء المشروع',
    ur: 'پراجیکٹ بنائیں',
    hi: 'परियोजना बनाएँ',
  );
  static const next = TranslatableString(
    en: 'Continue',
    ar: 'متابعة',
    ur: 'جاری رکھیں',
    hi: 'जारी रखें',
  );
  static const back = TranslatableString(
    en: 'Back',
    ar: 'رجوع',
    ur: 'واپس',
    hi: 'वापस',
  );
  static const skipForNow = TranslatableString(
    en: 'Skip for now',
    ar: 'تخطي الآن',
    ur: 'ابھی چھوڑ دیں',
    hi: 'अभी छोड़ें',
  );
  static const add = TranslatableString(
    en: 'Add',
    ar: 'إضافة',
    ur: 'شامل کریں',
    hi: 'जोड़ें',
  );
  static const remove = TranslatableString(
    en: 'Remove',
    ar: 'إزالة',
    ur: 'ہٹائیں',
    hi: 'हटाएँ',
  );
  static const edit = TranslatableString(
    en: 'Edit',
    ar: 'تعديل',
    ur: 'ترمیم کریں',
    hi: 'संपादित करें',
  );
  static const editProject = TranslatableString(
    en: 'Edit project',
    ar: 'تعديل المشروع',
    ur: 'پراجیکٹ میں ترمیم کریں',
    hi: 'परियोजना संपादित करें',
  );
  static const editProjectDescription = TranslatableString(
    en: 'Update the project setup, parties and buildings. Team access remains separately audited.',
    ar: 'حدّث إعداد المشروع والأطراف والمباني. يظل وصول الفريق مدققاً بشكل منفصل.',
    ur: 'پراجیکٹ سیٹ اپ، فریقین اور عمارتیں اپ ڈیٹ کریں۔ ٹیم کی رسائی الگ سے آڈٹ ہوتی ہے۔',
    hi: 'प्रोजेक्ट सेटअप, पक्षों और भवनों को अपडेट करें। टीम एक्सेस अलग से ऑडिट होता है।',
  );
  static const updateProject = TranslatableString(
    en: 'Update project',
    ar: 'تحديث المشروع',
    ur: 'پراجیکٹ اپ ڈیٹ کریں',
    hi: 'परियोजना अपडेट करें',
  );
  static const projectUpdated = TranslatableString(
    en: 'Project updated',
    ar: 'تم تحديث المشروع',
    ur: 'پراجیکٹ اپ ڈیٹ ہو گیا',
    hi: 'परियोजना अपडेट हुई',
  );
  static const projectUpdateFailed = TranslatableString(
    en: 'Project could not be updated',
    ar: 'تعذر تحديث المشروع',
    ur: 'پراجیکٹ اپ ڈیٹ نہیں ہو سکا',
    hi: 'परियोजना अपडेट नहीं हो सकी',
  );
  static const safeDeleteProject = TranslatableString(
    en: 'Archive project',
    ar: 'أرشفة المشروع',
    ur: 'پراجیکٹ آرکائیو کریں',
    hi: 'परियोजना संग्रहित करें',
  );
  static const safeDeleteProjectDescription = TranslatableString(
    en: 'This safely archives the project. Requests, documents and audit history are kept and it cannot be used while work is still open.',
    ar: 'يؤرشف هذا المشروع بأمان. تُحفظ الطلبات والمستندات وسجل التدقيق ولا يمكن استخدامه أثناء وجود عمل مفتوح.',
    ur: 'یہ پراجیکٹ کو محفوظ طور پر آرکائیو کرتا ہے۔ درخواستیں، دستاویزات اور آڈٹ ہسٹری محفوظ رہتی ہے اور کھلا کام ہونے پر استعمال نہیں ہو سکتا۔',
    hi: 'यह परियोजना को सुरक्षित रूप से संग्रहित करता है। अनुरोध, दस्तावेज़ और ऑडिट इतिहास सुरक्षित रहते हैं और खुले काम के दौरान इसका उपयोग नहीं हो सकता।',
  );
  static const archiveReason = TranslatableString(
    en: 'Archive reason',
    ar: 'سبب الأرشفة',
    ur: 'آرکائیو کرنے کی وجہ',
    hi: 'संग्रह कारण',
  );
  static const confirmArchive = TranslatableString(
    en: 'Archive safely',
    ar: 'أرشفة بأمان',
    ur: 'محفوظ طریقے سے آرکائیو کریں',
    hi: 'सुरक्षित रूप से संग्रहित करें',
  );
  static const cancel = TranslatableString(
    en: 'Cancel',
    ar: 'إلغاء',
    ur: 'منسوخ کریں',
    hi: 'रद्द करें',
  );

  static const projectDetails = TranslatableString(
    en: 'Project details',
    ar: 'تفاصيل المشروع',
    ur: 'پراجیکٹ کی تفصیلات',
    hi: 'परियोजना विवरण',
  );
  static const partiesAndAccess = TranslatableString(
    en: 'Parties & access',
    ar: 'الأطراف والوصول',
    ur: 'فریقین اور رسائی',
    hi: 'पक्ष और पहुँच',
  );
  static const buildings = TranslatableString(
    en: 'Buildings',
    ar: 'المباني',
    ur: 'عمارتیں',
    hi: 'भवन',
  );
  static const attachments = TranslatableString(
    en: 'Attachments',
    ar: 'المرفقات',
    ur: 'منسلکات',
    hi: 'संलग्नक',
  );
  static const reviewAndCreate = TranslatableString(
    en: 'Review & create',
    ar: 'مراجعة وإنشاء',
    ur: 'جائزہ اور تخلیق',
    hi: 'समीक्षा और निर्माण',
  );
  static const step = TranslatableString(
    en: 'Step',
    ar: 'الخطوة',
    ur: 'مرحلہ',
    hi: 'चरण',
  );

  static const yorksReference = TranslatableString(
    en: 'York Reference / Ref. No.',
    ar: 'مرجع يوركس',
    ur: 'یارکس حوالہ',
    hi: 'यॉर्क्स संदर्भ',
  );
  static const projectName = TranslatableString(
    en: 'Project name',
    ar: 'اسم المشروع',
    ur: 'پراجیکٹ کا نام',
    hi: 'परियोजना का नाम',
  );
  static const client = TranslatableString(
    en: 'Client',
    ar: 'العميل',
    ur: 'کلائنٹ',
    hi: 'ग्राहक',
  );
  static const jobOrContractReference = TranslatableString(
    en: 'Contract / Job No.',
    ar: 'مرجع العمل / العقد',
    ur: 'جاب / کنٹریکٹ حوالہ',
    hi: 'कार्य / अनुबंध संदर्भ',
  );
  static const siteLocation = TranslatableString(
    en: 'Site Location',
    ar: 'موقع المشروع',
    ur: 'سائٹ کا مقام',
    hi: 'साइट स्थान',
  );
  static const startDate = TranslatableString(
    en: 'Start date',
    ar: 'تاريخ البدء',
    ur: 'آغاز کی تاریخ',
    hi: 'आरंभ तिथि',
  );
  static const endDate = TranslatableString(
    en: 'Expected End Date',
    ar: 'تاريخ الانتهاء',
    ur: 'اختتامی تاریخ',
    hi: 'समाप्ति तिथि',
  );
  static const notes = TranslatableString(
    en: 'Project Notes',
    ar: 'ملاحظات',
    ur: 'نوٹس',
    hi: 'टिप्पणियाँ',
  );
  static const optional = TranslatableString(
    en: 'Optional',
    ar: 'اختياري',
    ur: 'اختیاری',
    hi: 'वैकल्पिक',
  );
  static const selectDate = TranslatableString(
    en: 'Select date',
    ar: 'اختر التاريخ',
    ur: 'تاریخ منتخب کریں',
    hi: 'तारीख चुनें',
  );
  static const yorksReferenceHint = TranslatableString(
    en: 'YRA-',
    ar: 'YRA-',
    ur: 'YRA-',
    hi: 'YRA-',
  );
  static const projectNameHint = TranslatableString(
    en: 'Enter project name',
    ar: 'أدخل اسم المشروع',
    ur: 'پراجیکٹ کا نام درج کریں',
    hi: 'परियोजना का नाम दर्ज करें',
  );
  static const clientHint = TranslatableString(
    en: 'Enter client or end user',
    ar: 'أدخل العميل أو المستخدم النهائي',
    ur: 'کلائنٹ یا آخری صارف درج کریں',
    hi: 'ग्राहक या अंतिम उपयोगकर्ता दर्ज करें',
  );
  static const jobOrContractReferenceHint = TranslatableString(
    en: 'Enter contract or job number',
    ar: 'أدخل رقم العقد أو العمل',
    ur: 'کنٹریکٹ یا جاب نمبر درج کریں',
    hi: 'अनुबंध या कार्य संख्या दर्ज करें',
  );
  static const siteLocationHint = TranslatableString(
    en: 'Area, city and site description',
    ar: 'المنطقة والمدينة ووصف الموقع',
    ur: 'علاقہ، شہر اور سائٹ کی تفصیل',
    hi: 'क्षेत्र, शहर और साइट विवरण',
  );
  static const notesHint = TranslatableString(
    en: 'Access, coordination or operational notes',
    ar: 'ملاحظات الوصول أو التنسيق أو التشغيل',
    ur: 'رسائی، رابطہ کاری یا عملی نوٹس',
    hi: 'पहुंच, समन्वय या संचालन संबंधी टिप्पणियाँ',
  );

  static const consultant = TranslatableString(
    en: 'Consultant',
    ar: 'الاستشاري',
    ur: 'کنسلٹنٹ',
    hi: 'परामर्शदाता',
  );
  static const mainContractor = TranslatableString(
    en: 'Main contractor',
    ar: 'المقاول الرئيسي',
    ur: 'مرکزی کنٹریکٹر',
    hi: 'मुख्य ठेकेदार',
  );
  static const subcontractors = TranslatableString(
    en: 'Subcontractors',
    ar: 'المقاولون من الباطن',
    ur: 'ذیلی کنٹریکٹرز',
    hi: 'उप-ठेकेदार',
  );
  static const otherContractors = TranslatableString(
    en: 'Other contractors',
    ar: 'مقاولون آخرون',
    ur: 'دیگر کنٹریکٹرز',
    hi: 'अन्य ठेकेदार',
  );
  static const projectEngineers = TranslatableString(
    en: 'Project Engineers',
    ar: 'مهندسو المشروع',
    ur: 'پراجیکٹ انجینئرز',
    hi: 'प्रोजेक्ट इंजीनियर',
  );
  static const projectTeam = TranslatableString(
    en: 'Project team',
    ar: 'فريق المشروع',
    ur: 'پراجیکٹ ٹیم',
    hi: 'परियोजना टीम',
  );
  static const manageTeam = TranslatableString(
    en: 'Manage Team',
    ar: 'إدارة الفريق',
    ur: 'ٹیم منظم کریں',
    hi: 'टीम प्रबंधित करें',
  );
  static const projectInformation = TranslatableString(
    en: 'Project Information',
    ar: 'معلومات المشروع',
    ur: 'پراجیکٹ کی معلومات',
    hi: 'परियोजना जानकारी',
  );
  static const procurementOwner = TranslatableString(
    en: 'Procurement Owner',
    ar: 'مسؤول المشتريات',
    ur: 'پروکیورمنٹ اونر',
    hi: 'खरीद स्वामी',
  );
  static const notAssigned = TranslatableString(
    en: 'Not assigned',
    ar: 'غير معيّن',
    ur: 'تفویض نہیں ہوا',
    hi: 'असाइन नहीं किया गया',
  );
  static const projectTeamDescription = TranslatableString(
    en: 'Project Engineers approve arrangements and manage Site Engineer access.',
    ar: 'يعتمد مهندسو المشروع الترتيبات ويديرون وصول مهندسي الموقع.',
    ur: 'پراجیکٹ انجینئر انتظامات منظور کرتے اور سائٹ انجینئر کی رسائی سنبھالتے ہیں۔',
    hi: 'प्रोजेक्ट इंजीनियर व्यवस्थाओं को मंज़ूर करते और साइट इंजीनियर की पहुँच प्रबंधित करते हैं।',
  );
  static const buildingsDescription = TranslatableString(
    en: 'A request can be for one building or Common / All Buildings.',
    ar: 'يمكن أن يكون الطلب لمبنى واحد أو مشترك / كل المباني.',
    ur: 'درخواست ایک عمارت یا کامن / تمام عمارتوں کے لیے ہو سکتی ہے۔',
    hi: 'अनुरोध एक भवन या कॉमन / सभी भवनों के लिए हो सकता है।',
  );
  static const teamChangesAudited = TranslatableString(
    en: 'Team changes are server-audited and available to the assigned Project Engineer.',
    ar: 'تغييرات الفريق مدققة على الخادم ومتاحة لمهندس المشروع المعيّن.',
    ur: 'ٹیم کی تبدیلیاں سرور پر آڈٹ ہوتی ہیں اور مقررہ پراجیکٹ انجینئر کے لیے دستیاب ہیں۔',
    hi: 'टीम परिवर्तन सर्वर पर ऑडिट होते हैं और नियुक्त प्रोजेक्ट इंजीनियर के लिए उपलब्ध हैं।',
  );
  static const projectTeamUpdated = TranslatableString(
    en: 'Project team updated',
    ar: 'تم تحديث فريق المشروع',
    ur: 'پراجیکٹ ٹیم اپ ڈیٹ ہو گئی',
    hi: 'प्रोजेक्ट टीम अपडेट की गई',
  );
  static const projectTeamChangeReason = TranslatableString(
    en: 'Updated project team assignment',
    ar: 'تم تحديث تعيين فريق المشروع',
    ur: 'پراجیکٹ ٹیم کی تفویض اپ ڈیٹ کی گئی',
    hi: 'प्रोजेक्ट टीम असाइनमेंट अपडेट किया गया',
  );
  static const manageProjectTeamTitle = TranslatableString(
    en: 'Manage Project Engineers & Site Engineers',
    ar: 'إدارة مهندسي المشروع والموقع',
    ur: 'پراجیکٹ اور سائٹ انجینئرز کا انتظام',
    hi: 'प्रोजेक्ट और साइट इंजीनियर प्रबंधित करें',
  );
  static const projectTeamPermissionRule = TranslatableString(
    en: 'Permission rule',
    ar: 'قاعدة الصلاحية',
    ur: 'اجازت کا اصول',
    hi: 'अनुमति नियम',
  );
  static const projectTeamPermissionDescription = TranslatableString(
    en: 'Project Engineers approve procurement arrangements and manage the team. Assigned Site Engineers may prepare BOQ items, raise requests and confirm site receipt.',
    ar: 'يعتمد مهندسو المشروع ترتيبات المشتريات ويديرون الفريق. يمكن لمهندسي الموقع المعيّنين إعداد عناصر جدول الكميات ورفع الطلبات وتأكيد استلام الموقع.',
    ur: 'پراجیکٹ انجینئر پروکیورمنٹ انتظامات منظور کرتے اور ٹیم منظم کرتے ہیں۔ تفویض شدہ سائٹ انجینئر BOQ آئٹمز تیار، درخواستیں اور سائٹ وصولی کی تصدیق کر سکتے ہیں۔',
    hi: 'प्रोजेक्ट इंजीनियर खरीद व्यवस्थाओं को मंज़ूर और टीम को प्रबंधित करते हैं। असाइन साइट इंजीनियर BOQ आइटम तैयार, अनुरोध और साइट प्राप्ति की पुष्टि कर सकते हैं।',
  );
  static const noProjectAccess = TranslatableString(
    en: 'No project access',
    ar: 'لا توجد صلاحية للمشروع',
    ur: 'پراجیکٹ تک رسائی نہیں',
    hi: 'कोई परियोजना पहुँच नहीं',
  );
  static const saveProjectTeam = TranslatableString(
    en: 'Save Project Team',
    ar: 'حفظ فريق المشروع',
    ur: 'پراجیکٹ ٹیم محفوظ کریں',
    hi: 'प्रोजेक्ट टीम सहेजें',
  );
  static const siteEngineers = TranslatableString(
    en: 'Site Engineers',
    ar: 'مهندسو الموقع',
    ur: 'سائٹ انجینئرز',
    hi: 'साइट इंजीनियर',
  );
  static const selectProjectEngineer = TranslatableString(
    en: 'Select a Project Engineer',
    ar: 'اختر مهندس مشروع',
    ur: 'پراجیکٹ انجینئر منتخب کریں',
    hi: 'प्रोजेक्ट इंजीनियर चुनें',
  );
  static const selectSiteEngineer = TranslatableString(
    en: 'Select a Site Engineer',
    ar: 'اختر مهندس موقع',
    ur: 'سائٹ انجینئر منتخب کریں',
    hi: 'साइट इंजीनियर चुनें',
  );
  static const loadingTeamDirectory = TranslatableString(
    en: 'Loading authorised team members…',
    ar: 'جارٍ تحميل أعضاء الفريق المخوّلين…',
    ur: 'مجاز ٹیم ممبران لوڈ ہو رہے ہیں…',
    hi: 'अधिकृत टीम सदस्य लोड हो रहे हैं…',
  );
  static const teamDirectoryUnavailable = TranslatableString(
    en: 'Authorised team members are unavailable right now. Try again while connected.',
    ar: 'أعضاء الفريق المخوّلون غير متاحين حالياً. حاول مرة أخرى أثناء الاتصال.',
    ur: 'مجاز ٹیم ممبران فی الحال دستیاب نہیں ہیں۔ کنکشن کے ساتھ دوبارہ کوشش کریں۔',
    hi: 'अधिकृत टीम सदस्य अभी उपलब्ध नहीं हैं। कनेक्ट रहते हुए फिर प्रयास करें।',
  );
  static const noEligibleTeamMembers = TranslatableString(
    en: 'No additional authorised team members are available.',
    ar: 'لا يتوفر أعضاء فريق مخوّلون إضافيون.',
    ur: 'مزید مجاز ٹیم ممبران دستیاب نہیں ہیں۔',
    hi: 'कोई अतिरिक्त अधिकृत टीम सदस्य उपलब्ध नहीं है।',
  );
  static const teamMemberNoLongerAvailable = TranslatableString(
    en: 'An added team member is no longer active. Remove them before creating the project.',
    ar: 'لم يعد عضو فريق مُضاف نشطاً. أزله قبل إنشاء المشروع.',
    ur: 'شامل کردہ ٹیم ممبر اب فعال نہیں ہے۔ پراجیکٹ بنانے سے پہلے اسے ہٹا دیں۔',
    hi: 'जोड़ा गया टीम सदस्य अब सक्रिय नहीं है। परियोजना बनाने से पहले उसे हटाएँ।',
  );
  static const profileId = TranslatableString(
    en: 'Authorised team member',
    ar: 'عضو فريق مخوّل',
    ur: 'مجاز ٹیم ممبر',
    hi: 'अधिकृत टीम सदस्य',
  );

  // ─── Foundation access administration ──────────────────────────
  static const commercialAccess = TranslatableString(
    en: 'Commercial access',
    ar: 'الوصول التجاري',
    ur: 'تجارتی رسائی',
    hi: 'वाणिज्यिक पहुँच',
  );
  static const commercialAccessDescription = TranslatableString(
    en: 'These protected controls affect only commercial visibility and management. The server records the reason for every change.',
    ar: 'تؤثر عناصر التحكم المحمية هذه في عرض البيانات التجارية وإدارتها فقط. يسجل الخادم سبب كل تغيير.',
    ur: 'یہ محفوظ کنٹرولز صرف تجارتی منظر اور انتظام پر اثر انداز ہوتے ہیں۔ سرور ہر تبدیلی کی وجہ ریکارڈ کرتا ہے۔',
    hi: 'ये सुरक्षित नियंत्रण केवल वाणिज्यिक दृश्यता और प्रबंधन को प्रभावित करते हैं। सर्वर हर बदलाव का कारण दर्ज करता है।',
  );
  static const viewCommercials = TranslatableString(
    en: 'View commercials',
    ar: 'عرض البيانات التجارية',
    ur: 'تجارتی معلومات دیکھیں',
    hi: 'वाणिज्यिक जानकारी देखें',
  );
  static const manageCommercials = TranslatableString(
    en: 'Manage commercials',
    ar: 'إدارة البيانات التجارية',
    ur: 'تجارتی معلومات کا انتظام کریں',
    hi: 'वाणिज्यिक जानकारी प्रबंधित करें',
  );
  static const roleDefault = TranslatableString(
    en: 'Role default',
    ar: 'الإعداد الافتراضي للدور',
    ur: 'رول کی طے شدہ رسائی',
    hi: 'भूमिका का डिफ़ॉल्ट',
  );
  static const customForUser = TranslatableString(
    en: 'Custom for this user',
    ar: 'مخصص لهذا المستخدم',
    ur: 'اس صارف کے لیے مخصوص',
    hi: 'इस उपयोगकर्ता के लिए कस्टम',
  );
  static const commercialAccessUnavailable = TranslatableString(
    en: 'Commercial access is unavailable right now. Try again while connected.',
    ar: 'الوصول التجاري غير متاح حالياً. حاول مرة أخرى أثناء الاتصال.',
    ur: 'تجارتی رسائی اس وقت دستیاب نہیں۔ کنکشن کے ساتھ دوبارہ کوشش کریں۔',
    hi: 'वाणिज्यिक पहुँच अभी उपलब्ध नहीं है। कनेक्ट रहते हुए फिर कोशिश करें।',
  );
  static const commercialAccessChangeReason = TranslatableString(
    en: 'Reason for access change',
    ar: 'سبب تغيير الوصول',
    ur: 'رسائی تبدیلی کی وجہ',
    hi: 'पहुंच परिवर्तन का कारण',
  );
  static const commercialAccessReasonHint = TranslatableString(
    en: 'Record why this access is needed or removed',
    ar: 'سجل سبب الحاجة إلى هذا الوصول أو إزالته',
    ur: 'یہ رسائی کیوں درکار یا ختم کی گئی ہے، ریکارڈ کریں',
    hi: 'यह पहुँच क्यों चाहिए या हटाई गई है, दर्ज करें',
  );
  static const saveAccessChange = TranslatableString(
    en: 'Save access change',
    ar: 'حفظ تغيير الوصول',
    ur: 'رسائی تبدیلی محفوظ کریں',
    hi: 'पहुंच परिवर्तन सहेजें',
  );
  static const accessUpdated = TranslatableString(
    en: 'Commercial access updated',
    ar: 'تم تحديث الوصول التجاري',
    ur: 'تجارتی رسائی اپ ڈیٹ ہو گئی',
    hi: 'वाणिज्यिक पहुँच अपडेट की गई',
  );
  static const addProjectEngineer = TranslatableString(
    en: 'Add Project Engineer',
    ar: 'إضافة مهندس مشروع',
    ur: 'پراجیکٹ انجینئر شامل کریں',
    hi: 'प्रोजेक्ट इंजीनियर जोड़ें',
  );
  static const addSiteEngineer = TranslatableString(
    en: 'Add Site Engineer',
    ar: 'إضافة مهندس موقع',
    ur: 'سائٹ انجینئر شامل کریں',
    hi: 'साइट इंजीनियर जोड़ें',
  );
  static const accessDescription = TranslatableString(
    en: 'Choose active, authorised team members. Team changes after creation are server-audited.',
    ar: 'اختر أعضاء فريق نشطين ومخوّلين. تُدقَّق تغييرات الفريق بعد الإنشاء على الخادم.',
    ur: 'فعال، مجاز ٹیم ممبران منتخب کریں۔ تخلیق کے بعد ٹیم کی تبدیلیاں سرور پر آڈٹ ہوتی ہیں۔',
    hi: 'सक्रिय, अधिकृत टीम सदस्य चुनें। निर्माण के बाद टीम परिवर्तन सर्वर पर ऑडिट होते हैं।',
  );
  static const initialProjectEngineerHint = TranslatableString(
    en: 'A Site Engineer may nominate an initial Project Engineer here. Activation still requires an active Project Engineer.',
    ar: 'يمكن لمهندس الموقع ترشيح مهندس مشروع أولي هنا. يظل التفعيل يتطلب مهندس مشروع نشطاً.',
    ur: 'سائٹ انجینئر یہاں ابتدائی پراجیکٹ انجینئر نامزد کر سکتا ہے۔ ایکٹیویشن کے لیے پھر بھی فعال پراجیکٹ انجینئر ضروری ہے۔',
    hi: 'साइट इंजीनियर यहाँ प्रारंभिक प्रोजेक्ट इंजीनियर नामित कर सकता है। सक्रिय करने के लिए फिर भी सक्रिय प्रोजेक्ट इंजीनियर जरूरी है।',
  );

  static const buildingCode = TranslatableString(
    en: 'Building code',
    ar: 'رمز المبنى',
    ur: 'عمارت کوڈ',
    hi: 'भवन कोड',
  );
  static const buildingName = TranslatableString(
    en: 'Building name',
    ar: 'اسم المبنى',
    ur: 'عمارت کا نام',
    hi: 'भवन का नाम',
  );
  static const floorsOrLevels = TranslatableString(
    en: 'Floors / levels',
    ar: 'الطوابق / المستويات',
    ur: 'فلورز / لیولز',
    hi: 'मंज़िलें / स्तर',
  );
  static const buildingNotes = TranslatableString(
    en: 'Building notes',
    ar: 'ملاحظات المبنى',
    ur: 'عمارت نوٹس',
    hi: 'भवन टिप्पणियाँ',
  );
  static const deliveryAddress = TranslatableString(
    en: 'Delivery address',
    ar: 'عنوان التسليم',
    ur: 'ڈیلیوری ایڈریس',
    hi: 'डिलीवरी पता',
  );
  static const hasFrpRoom = TranslatableString(
    en: 'Has FRP room',
    ar: 'به غرفة FRP',
    ur: 'FRP روم موجود ہے',
    hi: 'FRP कक्ष है',
  );
  static const addBuilding = TranslatableString(
    en: 'Add building',
    ar: 'إضافة مبنى',
    ur: 'عمارت شامل کریں',
    hi: 'भवन जोड़ें',
  );
  static const commonScope = TranslatableString(
    en: 'Common / All Buildings',
    ar: 'مشترك / جميع المباني',
    ur: 'مشترکہ / تمام عمارتیں',
    hi: 'साझा / सभी भवन',
  );
  static const commonScopeDescription = TranslatableString(
    en: 'The Common scope is created by the server and cannot be edited as a building.',
    ar: 'ينشئ الخادم النطاق المشترك ولا يمكن تعديله كمبنى.',
    ur: 'مشترکہ دائرہ سرور بناتا ہے اور اسے عمارت کے طور پر ترمیم نہیں کیا جا سکتا۔',
    hi: 'साझा दायरा सर्वर बनाता है और इसे भवन के रूप में संपादित नहीं किया जा सकता।',
  );
  static const buildingsIntro = TranslatableString(
    en: 'Add each project building separately. Building codes and names are project-specific. Floors are optional, and the FRP room decision is stored independently for every building.',
    ar: 'أضف كل مبنى للمشروع بشكل منفصل. رموز وأسماء المباني خاصة بالمشروع. الطوابق اختيارية، ويتم حفظ قرار غرفة FRP لكل مبنى بشكل مستقل.',
    ur: 'ہر پراجیکٹ عمارت الگ شامل کریں۔ عمارت کے کوڈ اور نام پراجیکٹ کے لیے مخصوص ہیں۔ فلورز اختیاری ہیں اور FRP روم کا فیصلہ ہر عمارت کے لیے الگ محفوظ ہوتا ہے۔',
    hi: 'प्रत्येक परियोजना भवन अलग जोड़ें। भवन कोड और नाम परियोजना-विशिष्ट हैं। मंज़िलें वैकल्पिक हैं और FRP कक्ष का निर्णय प्रत्येक भवन के लिए अलग सहेजा जाता है।',
  );
  static const noBuildingsAdded = TranslatableString(
    en: 'No buildings added yet',
    ar: 'لم تتم إضافة مبانٍ بعد',
    ur: 'ابھی کوئی عمارت شامل نہیں ہوئی',
    hi: 'अभी कोई भवन नहीं जोड़ा गया',
  );

  static const attachmentsOptionalTitle = TranslatableString(
    en: 'Attachments are optional',
    ar: 'المرفقات اختيارية',
    ur: 'منسلکات اختیاری ہیں',
    hi: 'संलग्नक वैकल्पिक हैं',
  );
  static const attachmentsOptionalDescription = TranslatableString(
    en: 'Add project documents now or later. Drawings, calculations, schedules, approvals and company material lists can be attached as the project develops.',
    ar: 'يمكنك تسجيل بيانات وصفية لمسودة المرفق الآن. يتم تسليم رفع الملفات الآمن وإصدارات المستندات في جزء المستندات.',
    ur: 'آپ ابھی ڈرافٹ منسلکات کا میٹا ڈیٹا درج کر سکتے ہیں۔ محفوظ فائل اپ لوڈ اور دستاویز ورژنز Documents سلائس میں فراہم ہوں گے۔',
    hi: 'आप अभी ड्राफ़्ट संलग्नक मेटाडेटा दर्ज कर सकते हैं। सुरक्षित फ़ाइल अपलोड और दस्तावेज़ संस्करण Documents स्लाइस में दिए जाएँगे।',
  );
  static const attachmentFileName = TranslatableString(
    en: 'File name',
    ar: 'اسم الملف',
    ur: 'فائل نام',
    hi: 'फ़ाइल नाम',
  );
  static const attachmentType = TranslatableString(
    en: 'Document type',
    ar: 'نوع المستند',
    ur: 'دستاویز کی قسم',
    hi: 'दस्तावेज़ प्रकार',
  );
  static const attachmentSize = TranslatableString(
    en: 'File size (bytes)',
    ar: 'حجم الملف (بايت)',
    ur: 'فائل سائز (بائٹس)',
    hi: 'फ़ाइल आकार (बाइट)',
  );
  static const attachmentReference = TranslatableString(
    en: 'Document reference',
    ar: 'مرجع المستند',
    ur: 'دستاویز حوالہ',
    hi: 'दस्तावेज़ संदर्भ',
  );
  static const addAttachment = TranslatableString(
    en: 'Add files',
    ar: 'إضافة سجل مرفق',
    ur: 'منسلکہ ریکارڈ شامل کریں',
    hi: 'संलग्नक रिकॉर्ड जोड़ें',
  );
  static const noAttachmentsAdded = TranslatableString(
    en: 'No attachments yet',
    ar: 'لم تتم إضافة سجلات مرفقات',
    ur: 'کوئی منسلکہ ریکارڈ شامل نہیں',
    hi: 'कोई संलग्नक रिकॉर्ड नहीं जोड़ा गया',
  );
  static const attachmentsDropzoneTitle = TranslatableString(
    en: 'Add project documents now or later',
    ar: 'أضف مستندات المشروع الآن أو لاحقاً',
    ur: 'پراجیکٹ دستاویزات ابھی یا بعد میں شامل کریں',
    hi: 'प्रोजेक्ट दस्तावेज़ अभी या बाद में जोड़ें',
  );
  static const attachmentsDropzoneDescription = TranslatableString(
    en: 'Drawings, calculations, schedules, approvals and company material lists can be attached as the project develops.',
    ar: 'يمكن إرفاق الرسومات والحسابات والجداول والموافقات وقوائم مواد الشركة مع تطور المشروع.',
    ur: 'ڈرائنگز، حسابات، شیڈولز، منظوریوں اور کمپنی کی مٹیریل لسٹیں پراجیکٹ کے ساتھ شامل کی جا سکتی ہیں۔',
    hi: 'परियोजना के साथ ड्रॉइंग, गणना, शेड्यूल, अनुमोदन और कंपनी सामग्री सूचियाँ जोड़ी जा सकती हैं।',
  );
  static const attachmentsDropzonePrompt = TranslatableString(
    en: 'Drag and drop files here, or select Add files.',
    ar: 'اسحب الملفات وأفلتها هنا أو اختر إضافة ملفات.',
    ur: 'فائلیں یہاں ڈریگ کر کے چھوڑیں یا فائلیں شامل کریں منتخب کریں۔',
    hi: 'फ़ाइलें यहां खींचकर छोड़ें या फ़ाइलें जोड़ें चुनें।',
  );
  static const attachmentsDropzoneActive = TranslatableString(
    en: 'Drop files to add them',
    ar: 'أفلت الملفات لإضافتها',
    ur: 'فائلیں شامل کرنے کے لیے چھوڑیں',
    hi: 'उन्हें जोड़ने के लिए फ़ाइलें छोड़ें',
  );
  static const attachmentsDoNotBlock = TranslatableString(
    en: 'This does not block project creation.',
    ar: 'لا يمنع ذلك إنشاء المشروع.',
    ur: 'یہ پراجیکٹ بنانے میں رکاوٹ نہیں ہے۔',
    hi: 'यह परियोजना निर्माण को नहीं रोकता।',
  );
  static const attachmentUploadFailed = TranslatableString(
    en: 'Project created. Some files can be uploaded later from Documents.',
    ar: 'تم إنشاء المشروع. يمكن رفع بعض الملفات لاحقاً من المستندات.',
    ur: 'پراجیکٹ بن گیا۔ کچھ فائلیں بعد میں Documents سے اپ لوڈ کی جا سکتی ہیں۔',
    hi: 'परियोजना बन गई। कुछ फ़ाइलें बाद में दस्तावेज़ों से अपलोड की जा सकती हैं।',
  );
  static const duplicateAttachment = TranslatableString(
    en: 'That file is already attached.',
    ar: 'هذا الملف مرفق بالفعل.',
    ur: 'یہ فائل پہلے ہی منسلک ہے۔',
    hi: 'यह फ़ाइल पहले से संलग्न है।',
  );
  static const attachmentReady = TranslatableString(
    en: 'Ready to upload',
    ar: 'جاهز للرفع',
    ur: 'اپ لوڈ کے لیے تیار',
    hi: 'अपलोड के लिए तैयार',
  );

  static const requiredField = TranslatableString(
    en: 'This field is required.',
    ar: 'هذا الحقل مطلوب.',
    ur: 'یہ فیلڈ ضروری ہے۔',
    hi: 'यह फ़ील्ड आवश्यक है।',
  );
  static const endDateAfterStart = TranslatableString(
    en: 'End date must be on or after the start date.',
    ar: 'يجب أن يكون تاريخ الانتهاء في أو بعد تاريخ البدء.',
    ur: 'اختتامی تاریخ آغاز کی تاریخ کے برابر یا بعد ہونی چاہیے۔',
    hi: 'समाप्ति तिथि आरंभ तिथि के बराबर या उसके बाद होनी चाहिए।',
  );
  static const projectDateSupportedRange = TranslatableString(
    en: 'Choose a project date within 50 years of today.',
    ar: 'اختر تاريخ مشروع ضمن 50 عاماً من اليوم.',
    ur: 'آج سے 50 سال کے اندر پراجیکٹ کی تاریخ منتخب کریں۔',
    hi: 'आज से 50 वर्षों के भीतर परियोजना की तारीख चुनें।',
  );
  static const atLeastOneBuilding = TranslatableString(
    en: 'Add at least one physical building.',
    ar: 'أضف مبنى فعلياً واحداً على الأقل.',
    ur: 'کم از کم ایک جسمانی عمارت شامل کریں۔',
    hi: 'कम से कम एक भौतिक भवन जोड़ें।',
  );
  static const duplicateBuildingCode = TranslatableString(
    en: 'Each building code must be unique.',
    ar: 'يجب أن يكون كل رمز مبنى فريداً.',
    ur: 'ہر عمارت کوڈ منفرد ہونا چاہیے۔',
    hi: 'हर भवन कोड अद्वितीय होना चाहिए।',
  );
  static const editBuilding = TranslatableString(
    en: 'Edit building',
    ar: 'تعديل المبنى',
    ur: 'عمارت میں ترمیم کریں',
    hi: 'भवन संपादित करें',
  );
  static const updateBuilding = TranslatableString(
    en: 'Update building',
    ar: 'تحديث المبنى',
    ur: 'عمارت اپ ڈیٹ کریں',
    hi: 'भवन अपडेट करें',
  );
  static const cancelBuildingEdit = TranslatableString(
    en: 'Cancel editing',
    ar: 'إلغاء التعديل',
    ur: 'ترمیم منسوخ کریں',
    hi: 'संपादन रद्द करें',
  );
  static const duplicateMember = TranslatableString(
    en: 'A team member can be added once only.',
    ar: 'يمكن إضافة عضو الفريق مرة واحدة فقط.',
    ur: 'ٹیم ممبر صرف ایک بار شامل ہو سکتا ہے۔',
    hi: 'टीम सदस्य केवल एक बार जोड़ा जा सकता है।',
  );
  static const stageNeedsAttention = TranslatableString(
    en: 'Complete the required fields before continuing.',
    ar: 'أكمل الحقول المطلوبة قبل المتابعة.',
    ur: 'جاری رکھنے سے پہلے ضروری فیلڈز مکمل کریں۔',
    hi: 'जारी रखने से पहले आवश्यक फ़ील्ड भरें।',
  );
  static const noPermission = TranslatableString(
    en: 'You do not have permission to create a project.',
    ar: 'ليس لديك صلاحية لإنشاء مشروع.',
    ur: 'آپ کو پراجیکٹ بنانے کی اجازت نہیں ہے۔',
    hi: 'आपको परियोजना बनाने की अनुमति नहीं है।',
  );
  static const noPermissionDescription = TranslatableString(
    en: 'Procurement can view authorized projects but cannot create or edit them.',
    ar: 'يمكن للمشتريات عرض المشاريع المصرح بها ولكن لا يمكنها إنشاؤها أو تعديلها.',
    ur: 'پروکیورمنٹ مجاز پراجیکٹس دیکھ سکتی ہے مگر بنا یا ترمیم نہیں کر سکتی۔',
    hi: 'प्रोक्योरमेंट अधिकृत परियोजनाएँ देख सकती है, लेकिन उन्हें बना या संपादित नहीं कर सकती।',
  );
  static const loadingAccess = TranslatableString(
    en: 'Checking project access…',
    ar: 'جارٍ التحقق من الوصول إلى المشروع…',
    ur: 'پراجیکٹ رسائی چیک ہو رہی ہے…',
    hi: 'परियोजना पहुँच जाँची जा रही है…',
  );
  static const signInRequired = TranslatableString(
    en: 'Sign in again to create a project.',
    ar: 'سجّل الدخول مرة أخرى لإنشاء مشروع.',
    ur: 'پراجیکٹ بنانے کے لیے دوبارہ سائن اِن کریں۔',
    hi: 'परियोजना बनाने के लिए फिर से साइन इन करें।',
  );

  static const portfolioDescription = TranslatableString(
    en: 'Authorized project context, current owner and connected work.',
    ar: 'سياق المشروع المصرح به والمالك الحالي والعمل المتصل.',
    ur: 'مجاز پراجیکٹ سیاق، موجودہ مالک اور منسلک کام۔',
    hi: 'अधिकृत परियोजना संदर्भ, वर्तमान स्वामी और जुड़ा हुआ कार्य।',
  );
  static const viewOnlyPortfolio = TranslatableString(
    en: 'View-only project context',
    ar: 'سياق مشروع للعرض فقط',
    ur: 'صرف دیکھنے کے لیے پراجیکٹ سیاق',
    hi: 'केवल देखने योग्य परियोजना संदर्भ',
  );
  static const searchProjects = TranslatableString(
    en: 'Search projects',
    ar: 'البحث في المشاريع',
    ur: 'پراجیکٹس تلاش کریں',
    hi: 'परियोजनाएँ खोजें',
  );
  static const allStates = TranslatableString(
    en: 'All states',
    ar: 'كل الحالات',
    ur: 'تمام حالتیں',
    hi: 'सभी स्थितियाँ',
  );
  static const noProjects = TranslatableString(
    en: 'No authorized projects yet',
    ar: 'لا توجد مشاريع مصرح بها حتى الآن',
    ur: 'ابھی کوئی مجاز پراجیکٹ نہیں',
    hi: 'अभी तक कोई अधिकृत परियोजना नहीं है',
  );
  static const noProjectsDescription = TranslatableString(
    en: 'Create a project to establish its Common scope, team history and BOQ groups together.',
    ar: 'أنشئ مشروعاً لتأسيس نطاقه المشترك وسجل فريقه ومجموعات جدول الكميات معاً.',
    ur: 'اس کا مشترک دائرہ، ٹیم ہسٹری اور BOQ گروپس ایک ساتھ قائم کرنے کے لیے پراجیکٹ بنائیں۔',
    hi: 'उसका साझा दायरा, टीम इतिहास और BOQ समूह एक साथ स्थापित करने के लिए परियोजना बनाएँ।',
  );
  static const noMatchingProjects = TranslatableString(
    en: 'No projects match this search or state filter.',
    ar: 'لا توجد مشاريع تطابق هذا البحث أو عامل تصفية الحالة.',
    ur: 'اس تلاش یا حالت فلٹر سے کوئی پراجیکٹ میل نہیں کھاتا۔',
    hi: 'इस खोज या स्थिति फ़िल्टर से कोई परियोजना मेल नहीं खाती।',
  );
  static const portfolioUnavailable = TranslatableString(
    en: 'Project context is unavailable right now. Refresh when connected.',
    ar: 'سياق المشروع غير متاح حالياً. حدّث عند الاتصال.',
    ur: 'پراجیکٹ سیاق فی الحال دستیاب نہیں۔ کنکشن پر ریفریش کریں۔',
    hi: 'परियोजना संदर्भ अभी उपलब्ध नहीं है। कनेक्ट होने पर रीफ़्रेश करें।',
  );
  static const retry = TranslatableString(
    en: 'Retry',
    ar: 'إعادة المحاولة',
    ur: 'دوبارہ کوشش کریں',
    hi: 'पुनः प्रयास करें',
  );
  static const openProject = TranslatableString(
    en: 'Open project',
    ar: 'فتح المشروع',
    ur: 'پراجیکٹ کھولیں',
    hi: 'परियोजना खोलें',
  );
  static const projectWorkspace = TranslatableString(
    en: 'Project workspace',
    ar: 'مساحة عمل المشروع',
    ur: 'پراجیکٹ ورک اسپیس',
    hi: 'परियोजना कार्यक्षेत्र',
  );
  static const workspaceDescription = TranslatableString(
    en: 'Review the controlled project context and continue through its connected records.',
    ar: 'راجع سياق المشروع المضبوط وتابع عبر سجلاته المتصلة.',
    ur: 'کنٹرولڈ پراجیکٹ سیاق کا جائزہ لیں اور اس کے منسلک ریکارڈز سے جاری رکھیں۔',
    hi: 'नियंत्रित परियोजना संदर्भ की समीक्षा करें और उसके जुड़े रिकॉर्ड से आगे बढ़ें।',
  );
  static const activateProject = TranslatableString(
    en: 'Activate project',
    ar: 'تفعيل المشروع',
    ur: 'پراجیکٹ فعال کریں',
    hi: 'परियोजना सक्रिय करें',
  );
  static const projectActivated = TranslatableString(
    en: 'Project activated.',
    ar: 'تم تفعيل المشروع.',
    ur: 'پراجیکٹ فعال ہو گیا۔',
    hi: 'परियोजना सक्रिय हो गई।',
  );
  static const projectActivationFailed = TranslatableString(
    en: 'Could not activate this project. Review the team and try again.',
    ar: 'تعذر تفعيل هذا المشروع. راجع الفريق وحاول مرة أخرى.',
    ur: 'یہ پراجیکٹ فعال نہیں ہو سکا۔ ٹیم کا جائزہ لے کر دوبارہ کوشش کریں۔',
    hi: 'यह परियोजना सक्रिय नहीं हो सकी। टीम की समीक्षा करके फिर प्रयास करें।',
  );
  static const overview = TranslatableString(
    en: 'Overview',
    ar: 'نظرة عامة',
    ur: 'جائزہ',
    hi: 'अवलोकन',
  );
  static const boq = TranslatableString(
    en: 'BOQ',
    ar: 'جدول الكميات',
    ur: 'BOQ',
    hi: 'बीओक्यू',
  );
  static const materialRequests = TranslatableString(
    en: 'Material Requests',
    ar: 'طلبات المواد',
    ur: 'میٹیریل ریکویسٹس',
    hi: 'सामग्री अनुरोध',
  );
  static const documents = TranslatableString(
    en: 'Documents',
    ar: 'المستندات',
    ur: 'دستاویزات',
    hi: 'दस्तावेज़',
  );
  static const projectFacts = TranslatableString(
    en: 'Project facts',
    ar: 'حقائق المشروع',
    ur: 'پراجیکٹ حقائق',
    hi: 'परियोजना तथ्य',
  );
  static const state = TranslatableString(
    en: 'State',
    ar: 'الحالة',
    ur: 'حالت',
    hi: 'स्थिति',
  );
  static const currentOwner = TranslatableString(
    en: 'Current owner',
    ar: 'المالك الحالي',
    ur: 'موجودہ مالک',
    hi: 'वर्तमान स्वामी',
  );
  static const site = TranslatableString(
    en: 'Site',
    ar: 'الموقع',
    ur: 'سائٹ',
    hi: 'साइट',
  );
  static const clientLabel = TranslatableString(
    en: 'Client',
    ar: 'العميل',
    ur: 'کلائنٹ',
    hi: 'ग्राहक',
  );
  static const buildingsActive = TranslatableString(
    en: 'Active buildings',
    ar: 'المباني النشطة',
    ur: 'فعال عمارتیں',
    hi: 'सक्रिय भवन',
  );
  static const activeTeam = TranslatableString(
    en: 'Active team',
    ar: 'الفريق النشط',
    ur: 'فعال ٹیم',
    hi: 'सक्रिय टीम',
  );
  static const updated = TranslatableString(
    en: 'Updated',
    ar: 'تم التحديث',
    ur: 'اپ ڈیٹ',
    hi: 'अपडेट किया गया',
  );
  static const openBoq = TranslatableString(
    en: 'Open BOQ',
    ar: 'فتح جدول الكميات',
    ur: 'BOQ کھولیں',
    hi: 'बीओक्यू खोलें',
  );
  static const openRequests = TranslatableString(
    en: 'Open material requests',
    ar: 'فتح طلبات المواد',
    ur: 'میٹیریل ریکویسٹس کھولیں',
    hi: 'सामग्री अनुरोध खोलें',
  );
  static const openDocuments = TranslatableString(
    en: 'Open documents',
    ar: 'فتح المستندات',
    ur: 'دستاویزات کھولیں',
    hi: 'दस्तावेज़ खोलें',
  );
  static const boqGroups = TranslatableString(
    en: 'BOQ Groups',
    ar: 'مجموعات جدول الكميات',
    ur: 'BOQ گروپس',
    hi: 'बीओक्यू समूह',
  );
  static const boqItems = TranslatableString(
    en: 'BOQ Items',
    ar: 'بنود جدول الكميات',
    ur: 'BOQ آئٹمز',
    hi: 'बीओक्यू आइटम',
  );
  static const requests = TranslatableString(
    en: 'Requests',
    ar: 'الطلبات',
    ur: 'درخواستیں',
    hi: 'अनुरोध',
  );
  static const foldersOfMaterials = TranslatableString(
    en: 'Folders of materials',
    ar: 'مجلدات المواد',
    ur: 'میٹیریل فولڈرز',
    hi: 'सामग्री फ़ोल्डर',
  );
  static const availableToRequest = TranslatableString(
    en: 'Available to request',
    ar: 'متاح للطلب',
    ur: 'درخواست کے لیے دستیاب',
    hi: 'अनुरोध के लिए उपलब्ध',
  );
  static const currentlyOpen = TranslatableString(
    en: 'currently open',
    ar: 'مفتوح حاليًا',
    ur: 'فی الحال کھلی',
    hi: 'वर्तमान में खुला',
  );
  static const projectLevelFiles = TranslatableString(
    en: 'Project-level files',
    ar: 'ملفات على مستوى المشروع',
    ur: 'پراجیکٹ لیول فائلز',
    hi: 'प्रोजेक्ट-स्तरीय फ़ाइलें',
  );
  static const plusCommonScope = TranslatableString(
    en: 'Plus Common scope',
    ar: 'بالإضافة إلى النطاق المشترك',
    ur: 'کامن اسکوپ کے علاوہ',
    hi: 'कॉमन स्कोप के साथ',
  );
  static const workspaceGuide = TranslatableString(
    en: 'Work from BOQ, Material Requests and Documents.',
    ar: 'اعمل من جدول الكميات وطلبات المواد والمستندات.',
    ur: 'BOQ، میٹیریل ریکویسٹس اور دستاویزات سے کام کریں۔',
    hi: 'बीओक्यू, सामग्री अनुरोध और दस्तावेज़ से काम करें।',
  );
  static const workspaceGuideDescription = TranslatableString(
    en: 'Procurement arrangement, approval, dispatch, receipt and returns remain inside the Material Request so nothing is lost between departments.',
    ar: 'يبقى ترتيب المشتريات والموافقة والإرسال والاستلام والمرتجعات داخل طلب المواد حتى لا يضيع شيء بين الأقسام.',
    ur: 'پروکیورمنٹ انتظام، منظوری، ڈسپیچ، وصولی اور ریٹرنز میٹیریل ریکویسٹ میں رہتے ہیں تاکہ شعبوں کے درمیان کچھ ضائع نہ ہو۔',
    hi: 'खरीद व्यवस्था, अनुमोदन, डिस्पैच, प्राप्ति और रिटर्न सामग्री अनुरोध में रहते हैं ताकि विभागों के बीच कुछ न खोए।',
  );
  static const groups = TranslatableString(
    en: 'groups',
    ar: 'مجموعات',
    ur: 'گروپس',
    hi: 'समूह',
  );
  static const items = TranslatableString(
    en: 'Items',
    ar: 'العناصر',
    ur: 'آئٹمز',
    hi: 'आइटम',
  );
  static const ready = TranslatableString(
    en: 'Ready',
    ar: 'جاهز',
    ur: 'تیار',
    hi: 'तैयार',
  );
  static const total = TranslatableString(
    en: 'Total',
    ar: 'الإجمالي',
    ur: 'کل',
    hi: 'कुल',
  );
  static const received = TranslatableString(
    en: 'Received',
    ar: 'تم الاستلام',
    ur: 'وصول شدہ',
    hi: 'प्राप्त',
  );
  static const files = TranslatableString(
    en: 'files',
    ar: 'ملفات',
    ur: 'فائلز',
    hi: 'फ़ाइलें',
  );
  static const links = TranslatableString(
    en: 'Links',
    ar: 'روابط',
    ur: 'لنکس',
    hi: 'लिंक',
  );
  static const boqModuleDescription = TranslatableString(
    en: 'Create folders, add materials and documents, or send an entire group to Procurement.',
    ar: 'أنشئ مجلدات وأضف موادًا ومستندات أو أرسل مجموعة كاملة إلى المشتريات.',
    ur: 'فولڈرز بنائیں، میٹیریل اور دستاویزات شامل کریں یا مکمل گروپ پروکیورمنٹ کو بھیجیں۔',
    hi: 'फ़ोल्डर बनाएं, सामग्री और दस्तावेज़ जोड़ें, या पूरा समूह खरीद को भेजें।',
  );
  static const requestsModuleDescription = TranslatableString(
    en: 'Request custom items or choose items already saved inside BOQ groups.',
    ar: 'اطلب عناصر مخصصة أو اختر عناصر محفوظة داخل مجموعات جدول الكميات.',
    ur: 'کسٹم آئٹمز کی درخواست کریں یا BOQ گروپس میں محفوظ آئٹمز منتخب کریں۔',
    hi: 'कस्टम आइटम का अनुरोध करें या बीओक्यू समूहों में सहेजे आइटम चुनें।',
  );
  static const documentsModuleDescription = TranslatableString(
    en: 'Upload or link the project files that engineers need from desktop, tablet or phone.',
    ar: 'ارفع أو اربط ملفات المشروع التي يحتاجها المهندسون من سطح المكتب أو الجهاز اللوحي أو الهاتف.',
    ur: 'وہ پراجیکٹ فائلز اپ لوڈ یا لنک کریں جو انجینئرز کو ڈیسک ٹاپ، ٹیبلٹ یا فون سے درکار ہیں۔',
    hi: 'डेस्कटॉप, टैबलेट या फोन से इंजीनियरों को आवश्यक प्रोजेक्ट फाइल अपलोड या लिंक करें।',
  );
  static const recentMaterialRequests = TranslatableString(
    en: 'Recent Material Requests',
    ar: 'طلبات المواد الأخيرة',
    ur: 'حالیہ میٹیریل ریکویسٹس',
    hi: 'हालिया सामग्री अनुरोध',
  );
  static const recentRequestsDescription = TranslatableString(
    en: 'The same request number and status are visible to Engineer and Procurement.',
    ar: 'رقم الطلب والحالة نفسيهما مرئيان للمهندس والمشتريات.',
    ur: 'وہی درخواست نمبر اور حالت انجینئر اور پروکیورمنٹ کو نظر آتے ہیں۔',
    hi: 'वही अनुरोध संख्या और स्थिति इंजीनियर और खरीद को दिखाई देते हैं।',
  );
  static const noRecentRequests = TranslatableString(
    en: 'No material requests yet',
    ar: 'لا توجد طلبات مواد بعد',
    ur: 'ابھی کوئی میٹیریل ریکویسٹ نہیں',
    hi: 'अभी कोई सामग्री अनुरोध नहीं',
  );
  static const requestsUnavailable = TranslatableString(
    en: 'Material Requests are unavailable right now.',
    ar: 'طلبات المواد غير متاحة حاليًا.',
    ur: 'میٹیریل ریکویسٹس فی الحال دستیاب نہیں ہیں۔',
    hi: 'सामग्री अनुरोध अभी उपलब्ध नहीं हैं।',
  );
  static const draftState = TranslatableString(
    en: 'Draft',
    ar: 'مسودة',
    ur: 'ڈرافٹ',
    hi: 'ड्राफ़्ट',
  );
  static const activeState = TranslatableString(
    en: 'Active',
    ar: 'نشط',
    ur: 'فعال',
    hi: 'सक्रिय',
  );
  static const onHoldState = TranslatableString(
    en: 'On hold',
    ar: 'معلق',
    ur: 'ہولڈ پر',
    hi: 'होल्ड पर',
  );
  static const completedState = TranslatableString(
    en: 'Completed',
    ar: 'مكتمل',
    ur: 'مکمل',
    hi: 'पूर्ण',
  );
  static const archivedState = TranslatableString(
    en: 'Archived',
    ar: 'مؤرشف',
    ur: 'آرکائیو شدہ',
    hi: 'संग्रहीत',
  );
  static const projectEngineerRole = TranslatableString(
    en: 'Project Engineer',
    ar: 'مهندس المشروع',
    ur: 'پراجیکٹ انجینئر',
    hi: 'प्रोजेक्ट इंजीनियर',
  );
  static const siteEngineerRole = TranslatableString(
    en: 'Site Engineer',
    ar: 'مهندس الموقع',
    ur: 'سائٹ انجینئر',
    hi: 'साइट इंजीनियर',
  );
  static const procurementRole = TranslatableString(
    en: 'Procurement',
    ar: 'المشتريات',
    ur: 'پروکیورمنٹ',
    hi: 'खरीद',
  );
  static const adminRole = TranslatableString(
    en: 'Admin',
    ar: 'المسؤول',
    ur: 'ایڈمن',
    hi: 'व्यवस्थापक',
  );

  static TranslatableString stateLabel(YorksV1ProjectLifecycle state) {
    return switch (state) {
      YorksV1ProjectLifecycle.draft => draftState,
      YorksV1ProjectLifecycle.active => activeState,
      YorksV1ProjectLifecycle.onHold => onHoldState,
      YorksV1ProjectLifecycle.completed => completedState,
      YorksV1ProjectLifecycle.archived => archivedState,
    };
  }

  static TranslatableString roleLabel(String? role) {
    return switch (role) {
      'project_engineer' => projectEngineerRole,
      'site_engineer' => siteEngineerRole,
      'procurement' => procurementRole,
      'admin' => adminRole,
      _ => projectTeam,
    };
  }

  static TranslatableString errorFor(YorksV1DomainErrorCode code) {
    return switch (code) {
      YorksV1DomainErrorCode.featureDisabled => const TranslatableString(
        en: 'Projects are not enabled for this rollout.',
        ar: 'المشاريع غير مفعلة لهذا الطرح.',
        ur: 'اس رول آؤٹ کے لیے پراجیکٹس فعال نہیں ہیں۔',
        hi: 'इस रोलआउट के लिए परियोजनाएँ सक्षम नहीं हैं।',
      ),
      YorksV1DomainErrorCode.offline => const TranslatableString(
        en: 'Connect to the internet before creating this project. Your draft is kept on this device.',
        ar: 'اتصل بالإنترنت قبل إنشاء هذا المشروع. يتم الاحتفاظ بمسودتك على هذا الجهاز.',
        ur: 'اس پراجیکٹ کو بنانے سے پہلے انٹرنیٹ سے جڑیں۔ آپ کا ڈرافٹ اس ڈیوائس پر محفوظ ہے۔',
        hi: 'इस परियोजना को बनाने से पहले इंटरनेट से कनेक्ट करें। आपका ड्राफ़्ट इस डिवाइस पर रखा गया है।',
      ),
      YorksV1DomainErrorCode.backendUnavailable => const TranslatableString(
        en: 'The project service is unavailable. Try again without changing the draft.',
        ar: 'خدمة المشروع غير متاحة. أعد المحاولة دون تغيير المسودة.',
        ur: 'پراجیکٹ سروس دستیاب نہیں۔ ڈرافٹ تبدیل کیے بغیر دوبارہ کوشش کریں۔',
        hi: 'परियोजना सेवा उपलब्ध नहीं है। ड्राफ़्ट बदले बिना फिर प्रयास करें।',
      ),
      YorksV1DomainErrorCode.unauthenticated => signInRequired,
      YorksV1DomainErrorCode.unauthorized => noPermission,
      YorksV1DomainErrorCode.invalidInput => stageNeedsAttention,
      YorksV1DomainErrorCode.invalidTransition => const TranslatableString(
        en: 'This project action is no longer available in its current state.',
        ar: 'إجراء المشروع هذا لم يعد متاحاً في حالته الحالية.',
        ur: 'یہ پراجیکٹ کارروائی موجودہ حالت میں اب دستیاب نہیں ہے۔',
        hi: 'यह परियोजना कार्रवाई अपनी वर्तमान स्थिति में अब उपलब्ध नहीं है।',
      ),
      YorksV1DomainErrorCode.conflict => const TranslatableString(
        en: 'This record changed elsewhere. Refresh and review the latest version.',
        ar: 'تم تغيير هذا السجل في مكان آخر. حدّث وراجع أحدث إصدار.',
        ur: 'یہ ریکارڈ کہیں اور تبدیل ہوا ہے۔ ریفریش کریں اور تازہ ورژن کا جائزہ لیں۔',
        hi: 'यह रिकॉर्ड कहीं और बदला है। ताज़ा करें और नवीनतम संस्करण की समीक्षा करें।',
      ),
      YorksV1DomainErrorCode.serverRejected => const TranslatableString(
        en: 'The server rejected this project. Review the details and try again.',
        ar: 'رفض الخادم هذا المشروع. راجع التفاصيل وحاول مرة أخرى.',
        ur: 'سرور نے اس پراجیکٹ کو مسترد کر دیا۔ تفصیلات کا جائزہ لیں اور دوبارہ کوشش کریں۔',
        hi: 'सर्वर ने इस परियोजना को अस्वीकार कर दिया। विवरण की समीक्षा करें और पुनः प्रयास करें।',
      ),
      YorksV1DomainErrorCode.unexpectedResponse => const TranslatableString(
        en: 'The project service returned an unexpected response. Your draft remains available.',
        ar: 'أعادت خدمة المشروع استجابة غير متوقعة. تبقى المسودة متاحة.',
        ur: 'پراجیکٹ سروس نے غیر متوقع جواب دیا۔ آپ کا ڈرافٹ دستیاب رہتا ہے۔',
        hi: 'परियोजना सेवा ने अनपेक्षित प्रतिक्रिया दी। आपका ड्राफ़्ट उपलब्ध रहता है।',
      ),
    };
  }
}
