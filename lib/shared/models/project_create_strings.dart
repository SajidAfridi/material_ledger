import 'app_strings.dart';

/// Copy contract for the V7 project-creation flow.
///
/// Kept separate from the legacy catalogue so the transformed module remains
/// easy to review and can be merged into a generated localization catalogue
/// when the rest of V7 is migrated.
abstract final class ProjectCreateStrings {
  static const eyebrow = TranslatableString(
    en: 'Projects',
    ar: 'المشاريع',
    ur: 'منصوبے',
    hi: 'परियोजनाएँ',
  );
  static const title = TranslatableString(
    en: 'Create project',
    ar: 'إنشاء مشروع',
    ur: 'منصوبہ بنائیں',
    hi: 'परियोजना बनाएँ',
  );
  static const subtitle = TranslatableString(
    en: 'Set the job up once so every plan, request and order stays connected.',
    ar: 'قم بإعداد العمل مرة واحدة لتظل كل خطة وطلب وأمر مترابطاً.',
    ur: 'کام ایک بار ترتیب دیں تاکہ ہر پلان، درخواست اور آرڈر منسلک رہے۔',
    hi: 'काम को एक बार सेट करें ताकि हर योजना, अनुरोध और आदेश जुड़ा रहे।',
  );
  static const stepOne = TranslatableString(
    en: 'Essentials & responsibility',
    ar: 'الأساسيات والمسؤولية',
    ur: 'بنیادی معلومات اور ذمہ داری',
    hi: 'मुख्य जानकारी और जिम्मेदारी',
  );
  static const stepTwo = TranslatableString(
    en: 'Buildings',
    ar: 'المباني',
    ur: 'عمارتیں',
    hi: 'इमारतें',
  );
  static const stepThree = TranslatableString(
    en: 'Review & create',
    ar: 'المراجعة والإنشاء',
    ur: 'جائزہ اور تخلیق',
    hi: 'समीक्षा और निर्माण',
  );
  static const stepOf = TranslatableString(
    en: 'Step',
    ar: 'الخطوة',
    ur: 'مرحلہ',
    hi: 'चरण',
  );
  static const essentialsDescription = TranslatableString(
    en: 'Project identity, dates, responsible people and optional parties.',
    ar: 'هوية المشروع وتواريخه والمسؤولون والأطراف الاختيارية.',
    ur: 'منصوبے کی شناخت، تاریخیں، ذمہ دار افراد اور اختیاری فریق۔',
    hi: 'परियोजना पहचान, तिथियाँ, जिम्मेदार लोग और वैकल्पिक पक्ष।',
  );
  static const buildingsDescription = TranslatableString(
    en: 'Add every physical building. Floors are optional; FRP is Yes or No.',
    ar: 'أضف كل مبنى فعلي. الطوابق اختيارية وFRP نعم أو لا.',
    ur: 'ہر عمارت شامل کریں۔ منزلیں اختیاری ہیں؛ FRP ہاں یا نہیں۔',
    hi: 'हर भौतिक इमारत जोड़ें। मंजिलें वैकल्पिक हैं; FRP हाँ या नहीं।',
  );
  static const reviewDescription = TranslatableString(
    en: 'Confirm the record before it becomes the project source of truth.',
    ar: 'أكد السجل قبل أن يصبح المصدر المعتمد للمشروع.',
    ur: 'ریکارڈ کی تصدیق کریں اس سے پہلے کہ یہ منصوبے کا مستند ذریعہ بنے۔',
    hi: 'रिकॉर्ड की पुष्टि करें, इससे पहले कि वह परियोजना का सत्य स्रोत बने।',
  );
  static const yorksReference = TranslatableString(
    en: 'Yorks reference',
    ar: 'مرجع يوركس',
    ur: 'یارکس حوالہ',
    hi: 'यॉर्क्स संदर्भ',
  );
  static const contractNumber = TranslatableString(
    en: 'Contract / job number',
    ar: 'رقم العقد / العمل',
    ur: 'معاہدہ / جاب نمبر',
    hi: 'अनुबंध / जॉब नंबर',
  );
  static const secondaryName = TranslatableString(
    en: 'Secondary project name',
    ar: 'اسم المشروع الثانوي',
    ur: 'ثانوی منصوبے کا نام',
    hi: 'द्वितीयक परियोजना नाम',
  );
  static const projectManager = TranslatableString(
    en: 'Project manager',
    ar: 'مدير المشروع',
    ur: 'پروجیکٹ مینیجر',
    hi: 'परियोजना प्रबंधक',
  );
  static const designEngineers = TranslatableString(
    en: 'Design / site engineers',
    ar: 'مهندسو التصميم / الموقع',
    ur: 'ڈیزائن / سائٹ انجینئرز',
    hi: 'डिज़ाइन / साइट इंजीनियर',
  );
  static const responsibilityHint = TranslatableString(
    en: 'Select at least one engineer so ownership and visibility are clear.',
    ar: 'اختر مهندساً واحداً على الأقل لتوضيح المسؤولية والرؤية.',
    ur: 'کم از کم ایک انجینئر منتخب کریں تاکہ ذمہ داری واضح ہو۔',
    hi: 'जिम्मेदारी और दृश्यता स्पष्ट रखने के लिए कम से कम एक इंजीनियर चुनें।',
  );
  static const consultant = TranslatableString(
    en: 'Consultant',
    ar: 'الاستشاري',
    ur: 'کنسلٹنٹ',
    hi: 'सलाहकार',
  );
  static const mainContractor = TranslatableString(
    en: 'Main contractor',
    ar: 'المقاول الرئيسي',
    ur: 'مرکزی ٹھیکیدار',
    hi: 'मुख्य ठेकेदार',
  );
  static const subcontractors = TranslatableString(
    en: 'Subcontractors',
    ar: 'المقاولون من الباطن',
    ur: 'ذیلی ٹھیکیدار',
    hi: 'उप-ठेकेदार',
  );
  static const otherContractors = TranslatableString(
    en: 'Other contractors',
    ar: 'مقاولون آخرون',
    ur: 'دیگر ٹھیکیدار',
    hi: 'अन्य ठेकेदार',
  );
  static const commaSeparated = TranslatableString(
    en: 'Separate multiple names with commas',
    ar: 'افصل بين الأسماء بفواصل',
    ur: 'متعدد نام کاما سے الگ کریں',
    hi: 'कई नामों को कॉमा से अलग करें',
  );
  static const building = TranslatableString(
    en: 'Building',
    ar: 'المبنى',
    ur: 'عمارت',
    hi: 'इमारत',
  );
  static const buildingCode = TranslatableString(
    en: 'Building code',
    ar: 'رمز المبنى',
    ur: 'عمارت کا کوڈ',
    hi: 'इमारत कोड',
  );
  static const buildingName = TranslatableString(
    en: 'Building name',
    ar: 'اسم المبنى',
    ur: 'عمارت کا نام',
    hi: 'इमारत का नाम',
  );
  static const floors = TranslatableString(
    en: 'Floors / levels',
    ar: 'الطوابق / المستويات',
    ur: 'منزلیں / سطحیں',
    hi: 'मंजिलें / स्तर',
  );
  static const floorsHint = TranslatableString(
    en: 'Optional, separated by commas',
    ar: 'اختياري، مفصولة بفواصل',
    ur: 'اختیاری، کاما سے الگ',
    hi: 'वैकल्पिक, कॉमा से अलग',
  );
  static const frpRoom = TranslatableString(
    en: 'FRP room',
    ar: 'غرفة FRP',
    ur: 'FRP کمرہ',
    hi: 'FRP कक्ष',
  );
  static const yes = TranslatableString(
    en: 'Yes',
    ar: 'نعم',
    ur: 'ہاں',
    hi: 'हाँ',
  );
  static const no = TranslatableString(
    en: 'No',
    ar: 'لا',
    ur: 'نہیں',
    hi: 'नहीं',
  );
  static const addBuilding = TranslatableString(
    en: 'Add building',
    ar: 'إضافة مبنى',
    ur: 'عمارت شامل کریں',
    hi: 'इमारत जोड़ें',
  );
  static const removeBuilding = TranslatableString(
    en: 'Remove building',
    ar: 'إزالة المبنى',
    ur: 'عمارت ہٹائیں',
    hi: 'इमारत हटाएँ',
  );
  static const documents = TranslatableString(
    en: 'Document references',
    ar: 'مراجع المستندات',
    ur: 'دستاویز کے حوالے',
    hi: 'दस्तावेज़ संदर्भ',
  );
  static const documentsDescription = TranslatableString(
    en: 'Optional metadata now; binary upload remains in the Documents workspace.',
    ar: 'بيانات وصفية اختيارية الآن؛ يبقى رفع الملف في مساحة المستندات.',
    ur: 'اب اختیاری میٹا ڈیٹا؛ اصل فائل دستاویزات ورک اسپیس میں اپ لوڈ ہوگی۔',
    hi: 'अभी वैकल्पिक मेटाडेटा; फ़ाइल अपलोड दस्तावेज़ कार्यक्षेत्र में रहेगा।',
  );
  static const addDocument = TranslatableString(
    en: 'Add document reference',
    ar: 'إضافة مرجع مستند',
    ur: 'دستاویز حوالہ شامل کریں',
    hi: 'दस्तावेज़ संदर्भ जोड़ें',
  );
  static const fileName = TranslatableString(
    en: 'File name',
    ar: 'اسم الملف',
    ur: 'فائل کا نام',
    hi: 'फ़ाइल नाम',
  );
  static const documentType = TranslatableString(
    en: 'Document type',
    ar: 'نوع المستند',
    ur: 'دستاویز کی قسم',
    hi: 'दस्तावेज़ प्रकार',
  );
  static const reference = TranslatableString(
    en: 'Reference',
    ar: 'المرجع',
    ur: 'حوالہ',
    hi: 'संदर्भ',
  );
  static const appliesTo = TranslatableString(
    en: 'Applies to',
    ar: 'ينطبق على',
    ur: 'اطلاق',
    hi: 'लागू क्षेत्र',
  );
  static const projectWide = TranslatableString(
    en: 'Project-wide / Common',
    ar: 'على مستوى المشروع / مشترك',
    ur: 'پورا منصوبہ / مشترکہ',
    hi: 'परियोजना-व्यापी / सामान्य',
  );
  static const noDocuments = TranslatableString(
    en: 'No document references added.',
    ar: 'لم تتم إضافة مراجع مستندات.',
    ur: 'کوئی دستاویز حوالہ شامل نہیں۔',
    hi: 'कोई दस्तावेज़ संदर्भ नहीं जोड़ा गया।',
  );
  static const reviewIdentity = TranslatableString(
    en: 'Project identity',
    ar: 'هوية المشروع',
    ur: 'منصوبے کی شناخت',
    hi: 'परियोजना पहचान',
  );
  static const responsibility = TranslatableString(
    en: 'Responsibility',
    ar: 'المسؤولية',
    ur: 'ذمہ داری',
    hi: 'जिम्मेदारी',
  );
  static const optionalParties = TranslatableString(
    en: 'Optional parties',
    ar: 'الأطراف الاختيارية',
    ur: 'اختیاری فریق',
    hi: 'वैकल्पिक पक्ष',
  );
  static const createdBy = TranslatableString(
    en: 'Created by',
    ar: 'أنشأه',
    ur: 'تخلیق کنندہ',
    hi: 'निर्माता',
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
  static const saveDraft = TranslatableString(
    en: 'Save draft',
    ar: 'حفظ المسودة',
    ur: 'مسودہ محفوظ کریں',
    hi: 'ड्राफ्ट सहेजें',
  );
  static const draftSaved = TranslatableString(
    en: 'Draft saved',
    ar: 'تم حفظ المسودة',
    ur: 'مسودہ محفوظ ہوگیا',
    hi: 'ड्राफ्ट सहेजा गया',
  );
  static const autosaved = TranslatableString(
    en: 'Changes save automatically',
    ar: 'يتم حفظ التغييرات تلقائياً',
    ur: 'تبدیلیاں خودکار محفوظ ہوتی ہیں',
    hi: 'बदलाव अपने आप सहेजे जाते हैं',
  );
  static const discardDraft = TranslatableString(
    en: 'Discard draft',
    ar: 'حذف المسودة',
    ur: 'مسودہ ختم کریں',
    hi: 'ड्राफ्ट हटाएँ',
  );
  static const discardQuestion = TranslatableString(
    en: 'Discard this unfinished project?',
    ar: 'هل تريد حذف هذا المشروع غير المكتمل؟',
    ur: 'یہ نامکمل منصوبہ ختم کریں؟',
    hi: 'इस अधूरी परियोजना को हटाएँ?',
  );
  static const create = TranslatableString(
    en: 'Create project',
    ar: 'إنشاء المشروع',
    ur: 'منصوبہ بنائیں',
    hi: 'परियोजना बनाएँ',
  );
  static const requiredMessage = TranslatableString(
    en: 'Complete the required fields before continuing.',
    ar: 'أكمل الحقول المطلوبة قبل المتابعة.',
    ur: 'جاری رکھنے سے پہلے مطلوبہ خانے مکمل کریں۔',
    hi: 'जारी रखने से पहले आवश्यक फ़ील्ड भरें।',
  );
  static const engineerRequired = TranslatableString(
    en: 'Select at least one design / site engineer.',
    ar: 'اختر مهندس تصميم / موقع واحداً على الأقل.',
    ur: 'کم از کم ایک ڈیزائن / سائٹ انجینئر منتخب کریں۔',
    hi: 'कम से कम एक डिज़ाइन / साइट इंजीनियर चुनें।',
  );
  static const startRequired = TranslatableString(
    en: 'Select a start date.',
    ar: 'اختر تاريخ البدء.',
    ur: 'شروع کی تاریخ منتخب کریں۔',
    hi: 'आरंभ तिथि चुनें।',
  );
  static const invalidEndDate = TranslatableString(
    en: 'Expected end date cannot be before the start date.',
    ar: 'لا يمكن أن يكون تاريخ الانتهاء المتوقع قبل تاريخ البدء.',
    ur: 'متوقع اختتامی تاریخ شروع کی تاریخ سے پہلے نہیں ہوسکتی۔',
    hi: 'अपेक्षित समाप्ति तिथि आरंभ तिथि से पहले नहीं हो सकती।',
  );
  static const referenceInUse = TranslatableString(
    en: 'This Yorks reference is already in use.',
    ar: 'مرجع يوركس هذا مستخدم بالفعل.',
    ur: 'یہ یارکس حوالہ پہلے سے استعمال میں ہے۔',
    hi: 'यह यॉर्क्स संदर्भ पहले से उपयोग में है।',
  );
  static const buildingRequired = TranslatableString(
    en: 'Add at least one complete physical building.',
    ar: 'أضف مبنى فعلياً كاملاً واحداً على الأقل.',
    ur: 'کم از کم ایک مکمل عمارت شامل کریں۔',
    hi: 'कम से कम एक पूर्ण भौतिक इमारत जोड़ें।',
  );
  static const duplicateBuildingCode = TranslatableString(
    en: 'Building codes must be unique.',
    ar: 'يجب أن تكون رموز المباني فريدة.',
    ur: 'عمارتوں کے کوڈ منفرد ہونے چاہئیں۔',
    hi: 'इमारत कोड अद्वितीय होने चाहिए।',
  );
  static const createFailed = TranslatableString(
    en: 'Project could not be created. Check the Yorks reference and try again.',
    ar: 'تعذر إنشاء المشروع. تحقق من مرجع يوركس وحاول مرة أخرى.',
    ur: 'منصوبہ نہیں بن سکا۔ یارکس حوالہ چیک کرکے دوبارہ کوشش کریں۔',
    hi: 'परियोजना नहीं बन सकी। यॉर्क्स संदर्भ जाँचकर फिर प्रयास करें।',
  );
  static const created = TranslatableString(
    en: 'Project created and connected to the project register.',
    ar: 'تم إنشاء المشروع وربطه بسجل المشاريع.',
    ur: 'منصوبہ بنایا گیا اور پروجیکٹ رجسٹر سے منسلک ہوگیا۔',
    hi: 'परियोजना बनाई गई और परियोजना रजिस्टर से जुड़ गई।',
  );
}
