import 'app_strings.dart';

/// Approved legal identity and contact copy shared by controlled Yorks
/// documents. Keeping this in one place prevents the Material Request and
/// Delivery Order from drifting into different letterheads or footers.
abstract final class YorksV1CompanyDocumentStrings {
  static const legalName = TranslatableString(
    en: 'YORKS Airconditioning & Refrigeration LLC-SPC',
    ar: 'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و',
    ur: 'یارکس ایئر کنڈیشننگ اینڈ ریفریجریشن ایل ایل سی-ایس پی سی',
    hi: 'यॉर्क्स एयर कंडीशनिंग एंड रेफ्रिजरेशन LLC-SPC',
  );

  static const contactLine = TranslatableString(
    en: 'Tel.: 02-5509788 - Fax: 02-5509688 - P.O. Box: 4757 - Abu Dhabi - United Arab Emirates',
    ar: 'هاتف: 02-5509788 - فاكس: 02-5509688 - ص.ب: 4757 - أبو ظبي - الإمارات العربية المتحدة',
    ur: 'ٹیلی فون: 02-5509788 - فیکس: 02-5509688 - پی او باکس: 4757 - ابوظہبی - متحدہ عرب امارات',
    hi: 'टेलीफोन: 02-5509788 - फैक्स: 02-5509688 - पी.ओ. बॉक्स: 4757 - अबू धाबी - संयुक्त अरब अमीरात',
  );

  static const email = 'yorks_sk@yorks.ae';

  static String qualifiedProjectName({
    required String projectName,
    String? jobContractReference,
  }) {
    final name = projectName.trim();
    final contract = jobContractReference?.trim() ?? '';
    return contract.isEmpty ? name : '$contract-$name';
  }
}
