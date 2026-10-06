import 'app_language.dart';
import 'app_strings.dart';

/// Display translations never replace stable imported fitting/material identifiers.
abstract final class YorksCalculatorEditorStrings {
  static String translate(String text, AppLanguage language) {
    final direct = _labels[text];
    if (direct != null) return direct.active(language);
    final incomplete = RegExp(r'^([0-9]+) incomplete row').firstMatch(text);
    if (incomplete != null) {
      return _incomplete
          .active(language)
          .replaceAll('{count}', incomplete.group(1)!);
    }
    final row = RegExp(r'^Line ([0-9]+)$').firstMatch(text);
    if (row != null) {
      return _line.active(language).replaceAll('{count}', row.group(1)!);
    }
    final count = RegExp(r'^([0-9]+) rows$').firstMatch(text);
    if (count != null) {
      return _rows.active(language).replaceAll('{count}', count.group(1)!);
    }
    return text;
  }

  static const _incomplete = TranslatableString(
    en: '{count} incomplete rows. Complete the duct data or enter a manufacturer/manual ESP before using the calculation.',
    ar: '{count} صفوف غير مكتملة. أكمل بيانات المجرى أو أدخل ضغطًا من المصنع أو يدويًا قبل استخدام الحساب.',
    ur: '{count} نامکمل قطاریں۔ حساب استعمال کرنے سے پہلے ڈکٹ ڈیٹا مکمل کریں یا دستی ESP درج کریں۔',
    hi: '{count} अधूरी पंक्तियाँ। गणना उपयोग से पहले डक्ट डेटा पूरा करें या निर्माता/मैनुअल ESP दर्ज करें।',
  );
  static const _line = TranslatableString(
    en: 'Line {count}',
    ar: 'الصف {count}',
    ur: 'قطار {count}',
    hi: 'पंक्ति {count}',
  );
  static const _rows = TranslatableString(
    en: '{count} rows',
    ar: '{count} صفوف',
    ur: '{count} قطاریں',
    hi: '{count} पंक्तियाँ',
  );
  static const _labels = <String, TranslatableString>{
    "Air distribution calculation": TranslatableString(
      en: "Air distribution calculation",
      ar: "حساب توزيع الهواء",
      ur: "ہوا کی تقسیم کا حساب",
      hi: "वायु वितरण गणना",
    ),
    "Duct sizing workspace": TranslatableString(
      en: "Duct sizing workspace",
      ar: "مساحة تحديد مقاس مجاري الهواء",
      ur: "ڈکٹ سائز کی جگہ",
      hi: "डक्ट आकार कार्यक्षेत्र",
    ),
    "Darcy-Weisbach friction with ASHRAE rectangular equivalent diameter.":
        TranslatableString(
          en: "Darcy-Weisbach friction with ASHRAE rectangular equivalent diameter.",
          ar: "احتكاك دارسي-وايسباخ مع القطر المكافئ المستطيل وفق ASHRAE.",
          ur: "دارسی وائسباخ رگڑ اور ASHRAE مستطیل مساوی قطر۔",
          hi: "डार्सी वाइसबाख घर्षण और ASHRAE आयताकार समतुल्य व्यास।",
        ),
    "External static pressure": TranslatableString(
      en: "External static pressure",
      ar: "الضغط الساكن الخارجي",
      ur: "بیرونی جامد دباؤ",
      hi: "बाहरी स्थिर दबाव",
    ),
    "System calculation workspace": TranslatableString(
      en: "System calculation workspace",
      ar: "مساحة حساب النظام",
      ur: "سسٹم حساب کی جگہ",
      hi: "सिस्टम गणना कार्यक्षेत्र",
    ),
    "Straight-duct losses use Darcy-Weisbach. Fittings use configurable K factors unless a manufacturer/manual ESP is entered.":
        TranslatableString(
          en: "Straight-duct losses use Darcy-Weisbach. Fittings use configurable K factors unless a manufacturer/manual ESP is entered.",
          ar: "تستخدم خسائر المجرى المستقيم دارسي-وايسباخ. تستخدم الوصلات معاملات K ما لم تُدخل قيمة ضغط من المصنع أو يدويًا.",
          ur: "سیدھی ڈکٹ کے نقصانات دارسی وائسباخ سے ہیں۔ دستی یا کارخانہ ESP نہ ہو تو فٹنگ K عوامل استعمال کرتی ہے۔",
          hi: "सीधी डक्ट हानि डार्सी वाइसबाख से है। निर्माता या मैनुअल ESP के बिना फिटिंग K कारक उपयोग करती है।",
        ),
    "Design basis": TranslatableString(
      en: "Design basis",
      ar: "أساس التصميم",
      ur: "ڈیزائن کی بنیاد",
      hi: "डिज़ाइन आधार",
    ),
    "Density": TranslatableString(
      en: "Density",
      ar: "الكثافة",
      ur: "کثافت",
      hi: "घनत्व",
    ),
    "Viscosity": TranslatableString(
      en: "Viscosity",
      ar: "اللزوجة",
      ur: "لزوجت",
      hi: "श्यानता",
    ),
    "Specific heat": TranslatableString(
      en: "Specific heat",
      ar: "الحرارة النوعية",
      ur: "مخصوص حرارت",
      hi: "विशिष्ट ऊष्मा",
    ),
    "Energy factor": TranslatableString(
      en: "Energy factor",
      ar: "معامل الطاقة",
      ur: "توانائی عامل",
      hi: "ऊर्जा कारक",
    ),
    "SI Units": TranslatableString(
      en: "SI Units",
      ar: "وحدات SI",
      ur: "SI اکائیاں",
      hi: "SI इकाइयाँ",
    ),
    "Imperial Units": TranslatableString(
      en: "Imperial Units",
      ar: "وحدات إمبراطورية",
      ur: "امپیریل اکائیاں",
      hi: "इम्पीरियल इकाइयाँ",
    ),
    "Inputs": TranslatableString(
      en: "Inputs",
      ar: "المدخلات",
      ur: "ان پٹ",
      hi: "इनपुट",
    ),
    "Design Parameters": TranslatableString(
      en: "Design Parameters",
      ar: "معايير التصميم",
      ur: "ڈیزائن پیرامیٹرز",
      hi: "डिज़ाइन मानदंड",
    ),
    "Flow Rate": TranslatableString(
      en: "Flow Rate",
      ar: "معدل التدفق",
      ur: "بہاؤ کی شرح",
      hi: "प्रवाह दर",
    ),
    "Duct Width": TranslatableString(
      en: "Duct Width",
      ar: "عرض المجرى",
      ur: "ڈکٹ کی چوڑائی",
      hi: "डक्ट चौड़ाई",
    ),
    "Duct Height": TranslatableString(
      en: "Duct Height",
      ar: "ارتفاع المجرى",
      ur: "ڈکٹ کی اونچائی",
      hi: "डक्ट ऊँचाई",
    ),
    "Duct Diameter": TranslatableString(
      en: "Duct Diameter",
      ar: "قطر المجرى",
      ur: "ڈکٹ کا قطر",
      hi: "डक्ट व्यास",
    ),
    "Duct Shape": TranslatableString(
      en: "Duct Shape",
      ar: "شكل المجرى",
      ur: "ڈکٹ کی شکل",
      hi: "डक्ट आकार",
    ),
    "Duct Material": TranslatableString(
      en: "Duct Material",
      ar: "مادة المجرى",
      ur: "ڈکٹ کا مواد",
      hi: "डक्ट सामग्री",
    ),
    "Rectangular": TranslatableString(
      en: "Rectangular",
      ar: "مستطيل",
      ur: "مستطیل",
      hi: "आयताकार",
    ),
    "Circular": TranslatableString(
      en: "Circular",
      ar: "دائري",
      ur: "گول",
      hi: "गोलाकार",
    ),
    "Check size": TranslatableString(
      en: "Check size",
      ar: "فحص المقاس",
      ur: "سائز جانچیں",
      hi: "आकार जाँचें",
    ),
    "Check Size": TranslatableString(
      en: "Check Size",
      ar: "فحص المقاس",
      ur: "سائز جانچیں",
      hi: "आकार जाँचें",
    ),
    "Size by Velocity": TranslatableString(
      en: "Size by Velocity",
      ar: "تحديد المقاس بالسرعة",
      ur: "رفتار کے مطابق سائز",
      hi: "वेग से आकार",
    ),
    "Size by Friction": TranslatableString(
      en: "Size by Friction",
      ar: "تحديد المقاس بالاحتكاك",
      ur: "رگڑ کے مطابق سائز",
      hi: "घर्षण से आकार",
    ),
    "Equivalent Diameter": TranslatableString(
      en: "Equivalent Diameter",
      ar: "القطر المكافئ",
      ur: "مساوی قطر",
      hi: "समतुल्य व्यास",
    ),
    "Known duct dimensions": TranslatableString(
      en: "Known duct dimensions",
      ar: "أبعاد المجرى المعروفة",
      ur: "معلوم ڈکٹ طول و عرض",
      hi: "ज्ञात डक्ट आयाम",
    ),
    "Target design velocity": TranslatableString(
      en: "Target design velocity",
      ar: "سرعة التصميم المستهدفة",
      ur: "مطلوب ڈیزائن رفتار",
      hi: "लक्षित डिज़ाइन वेग",
    ),
    "Target pressure loss": TranslatableString(
      en: "Target pressure loss",
      ar: "فقد الضغط المستهدف",
      ur: "مطلوب دباؤ کا نقصان",
      hi: "लक्षित दबाव हानि",
    ),
    "Known equivalent diameter": TranslatableString(
      en: "Known equivalent diameter",
      ar: "القطر المكافئ المعروف",
      ur: "معلوم مساوی قطر",
      hi: "ज्ञात समतुल्य व्यास",
    ),
    "Target Velocity": TranslatableString(
      en: "Target Velocity",
      ar: "السرعة المستهدفة",
      ur: "مطلوب رفتار",
      hi: "लक्षित वेग",
    ),
    "Target Friction Rate": TranslatableString(
      en: "Target Friction Rate",
      ar: "معدل الاحتكاك المستهدف",
      ur: "مطلوب رگڑ شرح",
      hi: "लक्षित घर्षण दर",
    ),
    "Aspect Ratio": TranslatableString(
      en: "Aspect Ratio",
      ar: "نسبة الأبعاد",
      ur: "طول عرض تناسب",
      hi: "पक्षानुपात",
    ),
    "Calculated results": TranslatableString(
      en: "Calculated results",
      ar: "النتائج المحسوبة",
      ur: "حساب شدہ نتائج",
      hi: "गणना परिणाम",
    ),
    "Hydraulic Performance": TranslatableString(
      en: "Hydraulic Performance",
      ar: "الأداء الهيدروليكي",
      ur: "ہائیڈرولک کارکردگی",
      hi: "हाइड्रॉलिक प्रदर्शन",
    ),
    "Checked duct size": TranslatableString(
      en: "Checked duct size",
      ar: "المقاس المفحوص",
      ur: "جانچا گیا ڈکٹ سائز",
      hi: "जाँचा गया डक्ट आकार",
    ),
    "Enter design parameters": TranslatableString(
      en: "Enter design parameters",
      ar: "أدخل معايير التصميم",
      ur: "ڈیزائن پیرامیٹرز درج کریں",
      hi: "डिज़ाइन मानदंड दर्ज करें",
    ),
    "Equivalent diameter": TranslatableString(
      en: "Equivalent diameter",
      ar: "القطر المكافئ",
      ur: "مساوی قطر",
      hi: "समतुल्य व्यास",
    ),
    "Hydraulic diameter": TranslatableString(
      en: "Hydraulic diameter",
      ar: "القطر الهيدروليكي",
      ur: "ہائیڈرولک قطر",
      hi: "हाइड्रॉलिक व्यास",
    ),
    "Flow area": TranslatableString(
      en: "Flow area",
      ar: "مساحة التدفق",
      ur: "بہاؤ کا رقبہ",
      hi: "प्रवाह क्षेत्र",
    ),
    "Fluid velocity": TranslatableString(
      en: "Fluid velocity",
      ar: "سرعة الهواء",
      ur: "ہوا کی رفتار",
      hi: "वायु वेग",
    ),
    "Reynolds number": TranslatableString(
      en: "Reynolds number",
      ar: "رقم رينولدز",
      ur: "رینالڈز نمبر",
      hi: "रेनॉल्ड्स संख्या",
    ),
    "Friction factor": TranslatableString(
      en: "Friction factor",
      ar: "معامل الاحتكاك",
      ur: "رگڑ عامل",
      hi: "घर्षण कारक",
    ),
    "Friction rate": TranslatableString(
      en: "Friction rate",
      ar: "معدل الاحتكاك",
      ur: "رگڑ شرح",
      hi: "घर्षण दर",
    ),
    "Velocity pressure": TranslatableString(
      en: "Velocity pressure",
      ar: "ضغط السرعة",
      ur: "رفتار کا دباؤ",
      hi: "वेग दाब",
    ),
    "Confirm final dimensions, allowable velocity, pressure drop, acoustic criteria and project specifications with the responsible HVAC Engineer.":
        TranslatableString(
          en: "Confirm final dimensions, allowable velocity, pressure drop, acoustic criteria and project specifications with the responsible HVAC Engineer.",
          ar: "تحقق من الأبعاد النهائية والسرعة المسموحة وفقد الضغط والمعايير الصوتية ومواصفات المشروع مع مهندس التكييف المسؤول.",
          ur: "حتمی طول و عرض، مجاز رفتار، دباؤ کا نقصان، صوتی معیار اور منصوبے کی تفصیلات متعلقہ HVAC انجینئر سے تصدیق کریں۔",
          hi: "अंतिम आयाम, अनुमत वेग, दबाव हानि, ध्वनि मानदंड और परियोजना विवरण जिम्मेदार HVAC इंजीनियर से सत्यापित करें।",
        ),
    "Project Name": TranslatableString(
      en: "Project Name",
      ar: "اسم المشروع",
      ur: "پروجیکٹ کا نام",
      hi: "परियोजना नाम",
    ),
    "Project No.": TranslatableString(
      en: "Project No.",
      ar: "رقم المشروع",
      ur: "پروجیکٹ نمبر",
      hi: "परियोजना संख्या",
    ),
    "System No.": TranslatableString(
      en: "System No.",
      ar: "رقم النظام",
      ur: "سسٹم نمبر",
      hi: "सिस्टम संख्या",
    ),
    "Revision": TranslatableString(
      en: "Revision",
      ar: "الإصدار",
      ur: "ورژن",
      hi: "संशोधन",
    ),
    "Date": TranslatableString(
      en: "Date",
      ar: "التاريخ",
      ur: "تاریخ",
      hi: "तारीख",
    ),
    "Equipment": TranslatableString(
      en: "Equipment",
      ar: "المعدات",
      ur: "آلات",
      hi: "उपकरण",
    ),
    "Add Row": TranslatableString(
      en: "Add Row",
      ar: "إضافة صف",
      ur: "قطار شامل کریں",
      hi: "पंक्ति जोड़ें",
    ),
    "Duplicate Last": TranslatableString(
      en: "Duplicate Last",
      ar: "نسخ آخر صف",
      ur: "آخری قطار نقل کریں",
      hi: "अंतिम पंक्ति की प्रतिलिपि",
    ),
    "Clear": TranslatableString(
      en: "Clear",
      ar: "مسح",
      ur: "صاف کریں",
      hi: "साफ़ करें",
    ),
    "Width/Height and Diameter are mutually exclusive. Manual ESP overrides the calculated value.":
        TranslatableString(
          en: "Width/Height and Diameter are mutually exclusive. Manual ESP overrides the calculated value.",
          ar: "لا يمكن الجمع بين العرض والارتفاع والقطر. تتجاوز قيمة الضغط اليدوية القيمة المحسوبة.",
          ur: "چوڑائی اور اونچائی یا قطر میں سے ایک استعمال کریں۔ دستی ESP حساب شدہ قدر کی جگہ لیتا ہے۔",
          hi: "चौड़ाई और ऊँचाई या व्यास में से एक उपयोग करें। मैनुअल ESP गणना मान का स्थान लेता है।",
        ),
    "Fitting Type": TranslatableString(
      en: "Fitting Type",
      ar: "نوع الوصلة",
      ur: "فٹنگ کی قسم",
      hi: "फिटिंग प्रकार",
    ),
    "Flow L/s": TranslatableString(
      en: "Flow L/s",
      ar: "التدفق L/s",
      ur: "بہاؤ L/s",
      hi: "प्रवाह L/s",
    ),
    "Width mm": TranslatableString(
      en: "Width mm",
      ar: "العرض mm",
      ur: "چوڑائی mm",
      hi: "चौड़ाई mm",
    ),
    "Height mm": TranslatableString(
      en: "Height mm",
      ar: "الارتفاع mm",
      ur: "اونچائی mm",
      hi: "ऊँचाई mm",
    ),
    "Length m": TranslatableString(
      en: "Length m",
      ar: "الطول m",
      ur: "لمبائی m",
      hi: "लंबाई m",
    ),
    "Diameter mm": TranslatableString(
      en: "Diameter mm",
      ar: "القطر mm",
      ur: "قطر mm",
      hi: "व्यास mm",
    ),
    "Manual ESP Pa": TranslatableString(
      en: "Manual ESP Pa",
      ar: "الضغط اليدوي Pa",
      ur: "دستی ESP Pa",
      hi: "मैनुअल ESP Pa",
    ),
    "Delete row": TranslatableString(
      en: "Delete row",
      ar: "حذف الصف",
      ur: "قطار حذف کریں",
      hi: "पंक्ति हटाएँ",
    ),
    "Safety Factor (%)": TranslatableString(
      en: "Safety Factor (%)",
      ar: "معامل الأمان (%)",
      ur: "حفاظتی عامل (%)",
      hi: "सुरक्षा कारक (%)",
    ),
    "Total external static pressure": TranslatableString(
      en: "Total external static pressure",
      ar: "إجمالي الضغط الساكن الخارجي",
      ur: "کل بیرونی جامد دباؤ",
      hi: "कुल बाहरी स्थिर दबाव",
    ),
    "Final ESP with safety factor": TranslatableString(
      en: "Final ESP with safety factor",
      ar: "الضغط النهائي بمعامل الأمان",
      ur: "حفاظتی عامل کے ساتھ حتمی ESP",
      hi: "सुरक्षा कारक सहित अंतिम ESP",
    ),
    "Straight Duct": TranslatableString(
      en: "Straight Duct",
      ar: "مجرى مستقيم",
      ur: "سیدھی ڈکٹ",
      hi: "सीधी डक्ट",
    ),
    "Elbow 90°": TranslatableString(
      en: "Elbow 90°",
      ar: "كوع 90°",
      ur: "موڑ 90°",
      hi: "मोड़ 90°",
    ),
    "Elbow 45°": TranslatableString(
      en: "Elbow 45°",
      ar: "كوع 45°",
      ur: "موڑ 45°",
      hi: "मोड़ 45°",
    ),
    "Reducer": TranslatableString(
      en: "Reducer",
      ar: "مخفض",
      ur: "ریڈیوسر",
      hi: "रिड्यूसर",
    ),
    "Expansion": TranslatableString(
      en: "Expansion",
      ar: "توسعة",
      ur: "توسیع",
      hi: "विस्तार",
    ),
    "Other": TranslatableString(
      en: "Other",
      ar: "أخرى",
      ur: "دیگر",
      hi: "अन्य",
    ),
    "Galvanized steel": TranslatableString(
      en: "Galvanized steel",
      ar: "فولاذ مجلفن",
      ur: "جستی اسٹیل",
      hi: "जस्ती स्टील",
    ),
    "Aluminium": TranslatableString(
      en: "Aluminium",
      ar: "ألمنيوم",
      ur: "ایلومینیم",
      hi: "एलुमिनियम",
    ),
    "Black steel": TranslatableString(
      en: "Black steel",
      ar: "فولاذ أسود",
      ur: "سیاہ اسٹیل",
      hi: "काला स्टील",
    ),
    "Flexible duct": TranslatableString(
      en: "Flexible duct",
      ar: "مجرى مرن",
      ur: "لچک دار ڈکٹ",
      hi: "लचीली डक्ट",
    ),
    "Concrete": TranslatableString(
      en: "Concrete",
      ar: "خرسانة",
      ur: "کنکریٹ",
      hi: "कंक्रीट",
    ),
    "Darcy-Weisbach duct friction": TranslatableString(
      en: "Darcy-Weisbach duct friction",
      ar: "احتكاك المجرى دارسي-وايسباخ",
      ur: "دارسی وائسباخ ڈکٹ رگڑ",
      hi: "डार्सी वाइसबाख डक्ट घर्षण",
    ),
    "Save": TranslatableString(
      en: "Save",
      ar: "حفظ",
      ur: "محفوظ کریں",
      hi: "सहेजें",
    ),
    "Import": TranslatableString(
      en: "Import",
      ar: "استيراد",
      ur: "درآمد کریں",
      hi: "आयात करें",
    ),
    "Export": TranslatableString(
      en: "Export",
      ar: "تصدير",
      ur: "برآمد کریں",
      hi: "निर्यात करें",
    ),
    "Print": TranslatableString(
      en: "Print",
      ar: "طباعة",
      ur: "پرنٹ",
      hi: "प्रिंट",
    ),
    "Fittings": TranslatableString(
      en: "Fittings",
      ar: "الوصلات",
      ur: "فٹنگز",
      hi: "फिटिंग",
    ),
    "ESP Fitting Library": TranslatableString(
      en: "ESP Fitting Library",
      ar: "مكتبة وصلات ESP",
      ur: "ESP فٹنگ لائبریری",
      hi: "ESP फिटिंग संग्रह",
    ),
    "Fitting": TranslatableString(
      en: "Fitting",
      ar: "الوصلة",
      ur: "فٹنگ",
      hi: "फिटिंग",
    ),
    "K coefficient": TranslatableString(
      en: "K coefficient",
      ar: "معامل K",
      ur: "K عامل",
      hi: "K गुणांक",
    ),
    "Close": TranslatableString(
      en: "Close",
      ar: "إغلاق",
      ur: "بند کریں",
      hi: "बंद करें",
    ),
    "Calculation imported.": TranslatableString(
      en: "Calculation imported.",
      ar: "تم استيراد الحساب.",
      ur: "حساب درآمد ہو گیا۔",
      hi: "गणना आयात हुई।",
    ),
    "Could not import this JSON file.": TranslatableString(
      en: "Could not import this JSON file.",
      ar: "تعذر استيراد ملف JSON.",
      ur: "یہ JSON فائل درآمد نہیں ہو سکی۔",
      hi: "यह JSON फ़ाइल आयात नहीं हो सकी।",
    ),
    "File exported.": TranslatableString(
      en: "File exported.",
      ar: "تم تصدير الملف.",
      ur: "فائل برآمد ہو گئی۔",
      hi: "फ़ाइल निर्यात हुई।",
    ),
  };
}
