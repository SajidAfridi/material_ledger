/// Supported app language modes.
///
/// English is always the primary content language.
/// The selected value controls the secondary translation layer.
/// If English is selected, secondary falls back to Arabic.
enum AppLanguage {
  english(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    subtitle: 'English + Arabic mode',
  ),
  arabic(
    code: 'ar',
    name: 'Arabic',
    nativeName: 'العربية',
    subtitle: 'اللغة العربية',
  ),
  urdu(
    code: 'ur',
    name: 'Urdu',
    nativeName: 'اردو',
    subtitle: 'پاکستان کی قومی زبان',
  ),
  hindi(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    subtitle: 'भारत की राजभाषा',
  );

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.subtitle,
  });

  final String code;
  final String name;
  final String nativeName;
  final String subtitle;

  /// Whether this language uses RTL writing direction.
  bool get isRtl => this == AppLanguage.arabic || this == AppLanguage.urdu;

  /// Resolve from stored code string.
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.arabic,
    );
  }
}
