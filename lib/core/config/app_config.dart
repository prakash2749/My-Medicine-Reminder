class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.supabase.medicinereminder://login-callback',
  );
  static const resetPasswordRedirectUrl = String.fromEnvironment(
    'RESET_PASSWORD_REDIRECT_URL',
    defaultValue: 'io.supabase.medicinereminder://reset-callback',
  );

  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. '
        'Run with --dart-define-from-file=config/dev.json',
      );
    }
  }
}
