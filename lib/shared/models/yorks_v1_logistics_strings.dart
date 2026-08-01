import 'app_strings.dart';
import 'yorks_v1_logistics.dart';

/// Centralized user-facing copy for the Batch 7 warehouse and logistics flow.
abstract final class YorksV1LogisticsStrings {
  static const inventory = TranslatableString(
    en: 'Warehouse inventory',
    ar: 'مخزون المستودع',
    ur: 'گودام کا ذخیرہ',
    hi: 'वेयरहाउस इन्वेंटरी',
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
    en: 'Item description',
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
  static const dispatchDate = TranslatableString(
    en: 'Dispatch date',
    ar: 'تاريخ الإرسال',
    ur: 'ڈسپیچ تاریخ',
    hi: 'डिस्पैच तारीख',
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
