/// Centralized phone number formatting and validation utility.
class PhoneUtils {
  PhoneUtils._();

  /// Formats raw phone number with country code into standardized E.164 (e.g. +15551234567)
  static String formatE164(String countryCode, String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    final code = countryCode.replaceAll(RegExp(r'[^\d]'), '');
    if (rawPhone.startsWith('+')) {
      return '+$digits';
    }
    return '+$code$digits';
  }

  /// Checks if a string conforms to the E.164 pattern (e.g. +15551234567)
  static bool isValidE164(String phone) {
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone);
  }
}
