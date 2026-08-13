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

  YorksV1NotificationRecord acknowledgedAt(DateTime value) =>
      YorksV1NotificationRecord(
        id: id,
        eventCode: eventCode,
        entityType: entityType,
        entityId: entityId,
        requestId: requestId,
        projectId: projectId,
        createdAt: createdAt,
        seenAt: value,
      );

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
    final resolvedProjectId = projectId?.trim() ?? '';
    return AppNotification(
      id: id,
      type: copy.type,
      title: copy.title(language),
      titleSecondary: '',
      body: copy.body(language),
      timestamp: createdAt,
      isRead: seenAt != null,
      refId: resolvedRequestId.isNotEmpty ? resolvedRequestId : entityId,
      route: resolvedRequestId.isNotEmpty
          ? RoutePaths.yorksV1MaterialRequestPath(resolvedRequestId)
          : resolvedProjectId.isNotEmpty &&
                (entityType == 'project' || entityType == 'project_member')
          ? RoutePaths.yorksV1ProjectPath(resolvedProjectId)
          : RoutePaths.notifications,
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

const _requestApprovalRequired = YorksV1NotificationCopy(
  type: NotificationType.request,
  englishTitle: 'Material request approval required',
  englishBody: 'A material request is ready for Engineering approval.',
  arabicTitle: 'مطلوب اعتماد طلب المواد',
  arabicBody: 'طلب مواد جاهز لاعتماد الهندسة.',
  urduTitle: 'مٹیریل ریکویسٹ کی منظوری درکار ہے',
  urduBody: 'مٹیریل ریکویسٹ انجینئرنگ منظوری کے لیے تیار ہے۔',
  hindiTitle: 'सामग्री अनुरोध की स्वीकृति आवश्यक',
  hindiBody: 'सामग्री अनुरोध इंजीनियरिंग स्वीकृति के लिए तैयार है।',
);

const _requestApprovedForArrangement = YorksV1NotificationCopy(
  type: NotificationType.request,
  englishTitle: 'Material request approved',
  englishBody: 'Engineering approved the request for Procurement arrangement.',
  arabicTitle: 'تم اعتماد طلب المواد',
  arabicBody: 'اعتمدت الهندسة الطلب لترتيب المشتريات.',
  urduTitle: 'مٹیریل ریکویسٹ منظور',
  urduBody: 'انجینئرنگ نے پروکیورمنٹ انتظام کے لیے ریکویسٹ منظور کر لی ہے۔',
  hindiTitle: 'सामग्री अनुरोध स्वीकृत',
  hindiBody: 'इंजीनियरिंग ने खरीद व्यवस्था के लिए अनुरोध स्वीकृत कर दिया है।',
);

const _requestChangesRequired = YorksV1NotificationCopy(
  type: NotificationType.request,
  englishTitle: 'Material request changes required',
  englishBody: 'Engineering returned the request with a reason.',
  arabicTitle: 'مطلوب تعديل طلب المواد',
  arabicBody: 'أعادت الهندسة الطلب مع السبب.',
  urduTitle: 'مٹیریل ریکویسٹ میں تبدیلی درکار ہے',
  urduBody: 'انجینئرنگ نے ریکویسٹ وجہ کے ساتھ واپس کر دی ہے۔',
  hindiTitle: 'सामग्री अनुरोध में बदलाव आवश्यक',
  hindiBody: 'इंजीनियरिंग ने कारण सहित अनुरोध वापस कर दिया है।',
);

const _requestMention = YorksV1NotificationCopy(
  type: NotificationType.info,
  englishTitle: 'You were mentioned',
  englishBody: 'A teammate mentioned you in a material request comment.',
  arabicTitle: 'تمت الإشارة إليك',
  arabicBody: 'أشار إليك زميل في تعليق على طلب مواد.',
  urduTitle: 'آپ کا ذکر کیا گیا',
  urduBody: 'ایک ساتھی نے مٹیریل ریکویسٹ کے تبصرے میں آپ کا ذکر کیا ہے۔',
  hindiTitle: 'आपका उल्लेख किया गया',
  hindiBody: 'एक साथी ने सामग्री अनुरोध टिप्पणी में आपका उल्लेख किया है।',
);

const _eventCopy = <String, YorksV1NotificationCopy>{
  'material_request_approval_required': _requestApprovalRequired,
  'material_request_updated_for_approval': _requestApprovalRequired,
  'material_request_approved_for_arrangement': _requestApprovedForArrangement,
  'material_request_changes_requested': _requestChangesRequired,
  'material_request_mentioned': _requestMention,
  'arrangement_ready_for_dispatch': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Materials ready for dispatch',
    englishBody: 'Procurement completed the approved arrangement.',
    arabicTitle: 'المواد جاهزة للصرف',
    arabicBody: 'أكملت المشتريات الترتيب المعتمد.',
    urduTitle: 'مٹیریل ڈسپیچ کے لیے تیار ہے',
    urduBody: 'پروکیورمنٹ نے منظور شدہ انتظام مکمل کر لیا ہے۔',
    hindiTitle: 'सामग्री डिस्पैच के लिए तैयार',
    hindiBody: 'खरीद ने स्वीकृत व्यवस्था पूरी कर ली है।',
  ),
  'arrangement_completed_unavailable': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Arrangement completed',
    englishBody:
        'Procurement recorded that no requested material can be provided now.',
    arabicTitle: 'اكتمل ترتيب الطلب',
    arabicBody: 'سجلت المشتريات أن المواد المطلوبة غير متاحة حالياً.',
    urduTitle: 'انتظام مکمل ہو گیا',
    urduBody: 'پروکیورمنٹ نے ریکارڈ کیا کہ مطلوبہ مواد ابھی دستیاب نہیں ہے۔',
    hindiTitle: 'व्यवस्था पूरी हुई',
    hindiBody: 'खरीद ने दर्ज किया कि अनुरोधित सामग्री अभी उपलब्ध नहीं है।',
  ),
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
  'material_return_confirmed': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Material return confirmed',
    englishBody:
        'Procurement confirmed physical receipt of the returned material.',
    arabicTitle: 'تم تأكيد مرتجع المواد',
    arabicBody: 'أكدت المشتريات الاستلام الفعلي للمواد المرتجعة.',
    urduTitle: 'مٹیریل ریٹرن کی تصدیق ہو گئی',
    urduBody: 'پروکیورمنٹ نے واپس شدہ مواد کی فزیکل وصولی کی تصدیق کر دی ہے۔',
    hindiTitle: 'सामग्री वापसी की पुष्टि हुई',
    hindiBody: 'खरीद ने लौटाई गई सामग्री की भौतिक प्राप्ति की पुष्टि की।',
  ),
  'material_return_rejected': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Material return rejected',
    englishBody: 'Procurement returned the material return with a reason.',
    arabicTitle: 'تم رفض مرتجع المواد',
    arabicBody: 'أعادت المشتريات مرتجع المواد مع السبب.',
    urduTitle: 'مٹیریل ریٹرن مسترد ہو گیا',
    urduBody: 'پروکیورمنٹ نے مٹیریل ریٹرن وجہ کے ساتھ واپس کر دیا ہے۔',
    hindiTitle: 'सामग्री वापसी अस्वीकृत हुई',
    hindiBody: 'खरीद ने कारण सहित सामग्री वापसी लौटा दी।',
  ),
  'material_request_cancelled': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Material request cancelled',
    englishBody:
        'The material request was cancelled and open work was released.',
    arabicTitle: 'تم إلغاء طلب المواد',
    arabicBody: 'تم إلغاء طلب المواد وتحرير العمل المفتوح.',
    urduTitle: 'مٹیریل ریکویسٹ منسوخ ہو گئی',
    urduBody: 'مٹیریل ریکویسٹ منسوخ کر کے کھلا کام جاری کر دیا گیا ہے۔',
    hindiTitle: 'सामग्री अनुरोध रद्द हुआ',
    hindiBody: 'सामग्री अनुरोध रद्द कर दिया गया और खुला कार्य मुक्त हुआ।',
  ),
  'material_request_closed': YorksV1NotificationCopy(
    type: NotificationType.request,
    englishTitle: 'Material request completed',
    englishBody: 'The received material request was closed.',
    arabicTitle: 'اكتمل طلب المواد',
    arabicBody: 'تم إغلاق طلب المواد المستلم.',
    urduTitle: 'مٹیریل ریکویسٹ مکمل ہو گئی',
    urduBody: 'موصولہ مٹیریل ریکویسٹ بند کر دی گئی ہے۔',
    hindiTitle: 'सामग्री अनुरोध पूरा हुआ',
    hindiBody: 'प्राप्त सामग्री अनुरोध बंद कर दिया गया।',
  ),
  'project_member_assigned': YorksV1NotificationCopy(
    type: NotificationType.project,
    englishTitle: 'Project access assigned',
    englishBody: 'You were assigned to a Yorks project.',
    arabicTitle: 'تم تعيين صلاحية المشروع',
    arabicBody: 'تم تعيينك في مشروع يوركس.',
    urduTitle: 'پروجیکٹ رسائی تفویض ہو گئی',
    urduBody: 'آپ کو یورکس پروجیکٹ میں تفویض کیا گیا ہے۔',
    hindiTitle: 'परियोजना पहुंच सौंपी गई',
    hindiBody: 'आपको यॉर्क्स परियोजना में नियुक्त किया गया है।',
  ),
  'project_member_revoked': YorksV1NotificationCopy(
    type: NotificationType.project,
    englishTitle: 'Project access changed',
    englishBody: 'Your active assignment to a Yorks project ended.',
    arabicTitle: 'تم تغيير صلاحية المشروع',
    arabicBody: 'انتهى تعيينك النشط في مشروع يوركس.',
    urduTitle: 'پروجیکٹ رسائی تبدیل ہو گئی',
    urduBody: 'یورکس پروجیکٹ میں آپ کی فعال تفویض ختم ہو گئی ہے۔',
    hindiTitle: 'परियोजना पहुंच बदली गई',
    hindiBody: 'यॉर्क्स परियोजना में आपकी सक्रिय नियुक्ति समाप्त हुई।',
  ),
};
