class AppConfig {
  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const String defaultUrl = 'https://tpafjedoogkwmeejjeaj.supabase.co';
  static const String defaultPublishableKey =
      'sb_publishable_4u0o1vPBsxN-bApqOuBJPw_8UG6dbOs';

  static String get supabaseUrl => _envUrl.isNotEmpty ? _envUrl : defaultUrl;
  static String get supabasePublishableKey =>
      _envKey.isNotEmpty ? _envKey : defaultPublishableKey;

  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. '
        'Run with --dart-define-from-file=config/dev.json',
      );
    }
  }
}