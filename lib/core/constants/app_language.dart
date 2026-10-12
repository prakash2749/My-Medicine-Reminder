/// Supported languages enum for Notify.
enum AppLanguage {
  english(
    code: 'en',
    displayName: 'English',
    nativeName: 'English',
  ),
  gujarati(
    code: 'gu',
    displayName: 'Gujarati',
    nativeName: 'ગુજરાતી',
  ),
  hindi(
    code: 'hi',
    displayName: 'Hindi',
    nativeName: 'हिन्दी',
  );

  final String code;
  final String displayName;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.displayName,
    required this.nativeName,
  });

  /// Parse language from string code (e.g. 'en', 'gu', 'hi')
  static AppLanguage fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'gu':
        return AppLanguage.gujarati;
      case 'hi':
        return AppLanguage.hindi;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}

/// Type alias for convenience
typedef Language = AppLanguage;
