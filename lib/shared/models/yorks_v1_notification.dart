import '../../app/router.dart' show RoutePaths;
import 'app_language.dart';
import 'app_notification.dart';

class YorksV1NotificationRecord {
  const YorksV1NotificationRecord({
    required this.id,
    required this.eventCode,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.requestId,
    this.projectId,
    this.seenAt,
  });

  final String id;
  final String eventCode;
  final String entityType;
  final String entityId;
  final String? requestId;
  final String? projectId;
  final DateTime createdAt;
  final DateTime? seenAt;

  factory YorksV1NotificationRecord.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1NotificationRecord(
      id: json['notification_id'] as String,
      eventCode: json['event_code'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      requestId: json['request_id'] as String?,
      projectId: json['project_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      seenAt: json['seen_at'] == null
          ? null
          : DateTime.parse(json['seen_at'] as String).toLocal(),
    );
  }

  AppNotification toAppNotification(AppLanguage language) {
    final copy = YorksV1NotificationCopy.forEvent(eventCode);
    final resolvedRequestId = requestId?.trim() ?? '';
    return AppNotification(
      id: id,
      type: copy.type,
      title: copy.title(language),
      titleSecondary: '',
      body: copy.body(language),
      timestamp: createdAt,
      isRead: seenAt != null,
      refId: resolvedRequestId.isNotEmpty ? resolvedRequestId : entityId,
      route: resolvedRequestId.isEmpty
          ? RoutePaths.notifications
          : RoutePaths.yorksV1MaterialRequestPath(resolvedRequestId),
      origin: NotificationOrigin.yorksV1,
    );
  }
}

class YorksV1NotificationCopy {
  const YorksV1NotificationCopy({
    required this.type,
    required this.englishTitle,
    required this.englishBody,
    required this.arabicTitle,
    required this.arabicBody,
    required this.urduTitle,
    required this.urduBody,
    required this.hindiTitle,
    required this.hindiBody,
  });

  final NotificationType type;
  final String englishTitle;
  final String englishBody;
  final String arabicTitle;
  final String arabicBody;
  final String urduTitle;
  final String urduBody;
  final String hindiTitle;
  final String hindiBody;

  String title(AppLanguage language) => switch (language) {
    AppLanguage.english => englishTitle,
    AppLanguage.arabic => arabicTitle,
    AppLanguage.urdu => urduTitle,
    AppLanguage.hindi => hindiTitle,
  };

  String body(AppLanguage language) => switch (language) {
    AppLanguage.english => englishBody,
    AppLanguage.arabic => arabicBody,
    AppLanguage.urdu => urduBody,
    AppLanguage.hindi => hindiBody,
  };

  static YorksV1NotificationCopy forEvent(String eventCode) =>
      _eventCopy[eventCode] ?? _workflowUpdate;
}

const _workflowUpdate = YorksV1NotificationCopy(
  type: NotificationType.info,
  englishTitle: 'Yorks workflow update',
  englishBody: 'A record assigned to you has changed.',
  arabicTitle: 'تحديث سير عمل يوركس',
  arabicBody: 'تم تغيير سجل مسند إليك.',
  urduTitle: 'یورکس ورک فلو اپ ڈیٹ',
  urduBody: 'آپ کو تفویض کردہ ریکارڈ تبدیل ہوا ہے۔',
  hindiTitle: 'यॉर्क्स कार्यप्रवाह अपडेट',
  hindiBody: 'आपको सौंपा गया रिकॉर्ड बदल गया है।',
);

const _eventCopy = <String, YorksV1NotificationCopy>{
  'material_request_submitted': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'New material request',
    englishBody: 'A material request is ready for Procurement arrangement.',
    arabicTitle: 'طلب مواد جديد',
    arabicBody: 'طلب مواد جاهز لترتيب المشتريات.',
    urduTitle: 'نئی مٹیریل ریکویسٹ',
    urduBody: 'مٹیریل ریکویسٹ پروکیورمنٹ انتظام کے لیے تیار ہے۔',
    hindiTitle: 'नया सामग्री अनुरोध',
    hindiBody: 'सामग्री अनुरोध खरीद व्यवस्था के लिए तैयार है।',
  ),
  'arrangement_review_required': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Arrangement ready for review',
    englishBody:
        'Procurement submitted an arrangement for Engineering approval.',
    arabicTitle: 'الترتيب جاهز للمراجعة',
    arabicBody: 'قدمت المشتريات ترتيباً لاعتماد الهندسة.',
    urduTitle: 'انتظام جائزے کے لیے تیار',
    urduBody: 'پروکیورمنٹ نے انجینئرنگ منظوری کے لیے انتظام جمع کیا ہے۔',
    hindiTitle: 'व्यवस्था समीक्षा के लिए तैयार',
    hindiBody: 'खरीद ने इंजीनियरिंग अनुमोदन के लिए व्यवस्था भेजी है।',
  ),
  'arrangement_approved': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Arrangement approved',
    englishBody: 'The material request is ready for controlled dispatch.',
    arabicTitle: 'تم اعتماد الترتيب',
    arabicBody: 'طلب المواد جاهز للصرف المنضبط.',
    urduTitle: 'انتظام منظور ہو گیا',
    urduBody: 'مٹیریل ریکویسٹ کنٹرولڈ ڈسپیچ کے لیے تیار ہے۔',
    hindiTitle: 'व्यवस्था स्वीकृत',
    hindiBody: 'सामग्री अनुरोध नियंत्रित डिस्पैच के लिए तैयार है।',
  ),
  'arrangement_returned': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Arrangement returned',
    englishBody: 'Engineering returned the arrangement to Procurement.',
    arabicTitle: 'تمت إعادة الترتيب',
    arabicBody: 'أعادت الهندسة الترتيب إلى المشتريات.',
    urduTitle: 'انتظام واپس کر دیا گیا',
    urduBody: 'انجینئرنگ نے انتظام پروکیورمنٹ کو واپس کیا ہے۔',
    hindiTitle: 'व्यवस्था लौटाई गई',
    hindiBody: 'इंजीनियरिंग ने व्यवस्था खरीद को लौटा दी है।',
  ),
  'receipt_review_required': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Delivery ready for receipt review',
    englishBody: 'Dispatched materials are awaiting the project team review.',
    arabicTitle: 'التسليم جاهز لمراجعة الاستلام',
    arabicBody: 'المواد المصروفة بانتظار مراجعة فريق المشروع.',
    urduTitle: 'ڈیلیوری وصولی جائزے کے لیے تیار',
    urduBody: 'بھیجا گیا مواد پروجیکٹ ٹیم کے جائزے کا منتظر ہے۔',
    hindiTitle: 'डिलीवरी प्राप्ति समीक्षा के लिए तैयार',
    hindiBody: 'भेजी गई सामग्री परियोजना टीम की समीक्षा की प्रतीक्षा में है।',
  ),
  'receipt_review_confirmed': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Receipt review confirmed',
    englishBody: 'The project team recorded the delivered material condition.',
    arabicTitle: 'تم تأكيد مراجعة الاستلام',
    arabicBody: 'سجل فريق المشروع حالة المواد المسلمة.',
    urduTitle: 'وصولی جائزے کی تصدیق ہو گئی',
    urduBody: 'پروجیکٹ ٹیم نے موصولہ مواد کی حالت ریکارڈ کر دی ہے۔',
    hindiTitle: 'प्राप्ति समीक्षा की पुष्टि हुई',
    hindiBody: 'परियोजना टीम ने वितरित सामग्री की स्थिति दर्ज की है।',
  ),
  'material_return_submitted': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Material return submitted',
    englishBody:
        'A project material return is awaiting Procurement confirmation.',
    arabicTitle: 'تم تقديم مرتجع مواد',
    arabicBody: 'مرتجع مواد المشروع بانتظار تأكيد المشتريات.',
    urduTitle: 'مٹیریل ریٹرن جمع ہو گیا',
    urduBody: 'پروجیکٹ مٹیریل ریٹرن پروکیورمنٹ تصدیق کا منتظر ہے۔',
    hindiTitle: 'सामग्री वापसी जमा हुई',
    hindiBody: 'परियोजना सामग्री वापसी खरीद पुष्टि की प्रतीक्षा में है।',
  ),
};
