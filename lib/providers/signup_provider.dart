import 'package:flutter/material.dart';
import '../core/constants/app_language.dart';

/// Manages multi-step onboarding & signup state across the setup flow.
class SignupProvider extends ChangeNotifier {
  // Purpose choices directly mapped from requirements & screenshot
  static const List<String> availablePurposes = [
    'Get medication reminders',
    'Track whether I took my meds',
    'Keep a list of my meds',
    'Remember when it’s time to refill',
    'Check for drug interaction',
    'Track side effects / symptoms',
    'Track measurements (e.g. Blood Pressure)',
  ];

  // Gender options
  static const List<String> availableGenders = [
    'Female',
    'Male',
  ];

  // Relationship options for Care Circle
  static const List<String> availableRelationships = [
    'Parent',
    'Partner',
    'Sibling',
    'Friend',
    'Caregiver',
    'Child',
    'Other',
  ];

  // --- Preferred Language ---
  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  void setLanguage(AppLanguage lang) {
    _language = lang;
    notifyListeners();
  }

  // --- Step 1: Personal Info ---
  String _name = '';
  DateTime? _birthDate;
  String? _gender;
  String _customGender = '';

  String get name => _name;
  DateTime? get birthDate => _birthDate;
  String? get gender => _gender;
  String get customGender => _customGender;

  void setName(String val) {
    _name = val.trim();
    notifyListeners();
  }

  void setBirthDate(DateTime? val) {
    _birthDate = val;
    notifyListeners();
  }

  void setGender(String? val) {
    _gender = val;
    if (val != 'Custom') {
      _customGender = '';
    }
    notifyListeners();
  }

  void setCustomGender(String val) {
    _customGender = val.trim();
    notifyListeners();
  }

  bool get isPersonalInfoValid => _name.trim().isNotEmpty && _birthDate != null;

  // --- Step 2: Purpose (from screenshot) ---
  final Set<String> _selectedPurposes = {};
  Set<String> get selectedPurposes => Set.unmodifiable(_selectedPurposes);

  void togglePurpose(String purpose) {
    if (_selectedPurposes.contains(purpose)) {
      _selectedPurposes.remove(purpose);
    } else {
      _selectedPurposes.add(purpose);
    }
    notifyListeners();
  }

  void clearPurposes() {
    _selectedPurposes.clear();
    notifyListeners();
  }

  // --- Step 3: My Day ---
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _bedtimeTime = const TimeOfDay(hour: 22, minute: 30);
  bool _isRoutineFlexible = false;

  TimeOfDay get wakeUpTime => _wakeUpTime;
  TimeOfDay get breakfastTime => _breakfastTime;
  TimeOfDay get lunchTime => _lunchTime;
  TimeOfDay get dinnerTime => _dinnerTime;
  TimeOfDay get bedtimeTime => _bedtimeTime;
  bool get isRoutineFlexible => _isRoutineFlexible;

  void setWakeUpTime(TimeOfDay val) {
    _wakeUpTime = val;
    notifyListeners();
  }

  void setBreakfastTime(TimeOfDay val) {
    _breakfastTime = val;
    notifyListeners();
  }

  void setLunchTime(TimeOfDay val) {
    _lunchTime = val;
    notifyListeners();
  }

  void setDinnerTime(TimeOfDay val) {
    _dinnerTime = val;
    notifyListeners();
  }

  void setBedtimeTime(TimeOfDay val) {
    _bedtimeTime = val;
    notifyListeners();
  }

  void setIsRoutineFlexible(bool val) {
    _isRoutineFlexible = val;
    notifyListeners();
  }

  // --- Step 4: Care Circle ---
  bool _wantsCareCircle = false;
  String _contactName = '';
  String _countryCode = '+1';
  String _phoneNumber = '';
  String? _relationship;
  int _alertDelayMinutes = 30;
  bool _agreedToShareAlerts = false;

  bool get wantsCareCircle => _wantsCareCircle;
  String get contactName => _contactName;
  String get countryCode => _countryCode;
  String get phoneNumber => _phoneNumber;
  String? get relationship => _relationship;
  int get alertDelayMinutes => _alertDelayMinutes;
  bool get agreedToShareAlerts => _agreedToShareAlerts;

  void setWantsCareCircle(bool val) {
    _wantsCareCircle = val;
    notifyListeners();
  }

  void setContactName(String val) {
    _contactName = val.trim();
    notifyListeners();
  }

  void setCountryCode(String val) {
    _countryCode = val.trim();
    notifyListeners();
  }

  void setPhoneNumber(String val) {
    _phoneNumber = val.trim();
    notifyListeners();
  }

  void setRelationship(String? val) {
    _relationship = val;
    notifyListeners();
  }

  void setAlertDelayMinutes(int val) {
    _alertDelayMinutes = val;
    notifyListeners();
  }

  void setAgreedToShareAlerts(bool val) {
    _agreedToShareAlerts = val;
    notifyListeners();
  }

  bool get isCareCircleValid {
    if (!_wantsCareCircle) return true;
    return _contactName.isNotEmpty &&
        _phoneNumber.isNotEmpty &&
        _agreedToShareAlerts;
  }

  // --- Step 5: Account Credentials ---
  String _email = '';
  String _password = '';
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get email => _email;
  String get password => _password;
  bool get agreedToTerms => _agreedToTerms;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void setEmail(String val) {
    _email = val.trim();
    _errorMessage = null;
    notifyListeners();
  }

  void setPassword(String val) {
    _password = val;
    _errorMessage = null;
    notifyListeners();
  }

  void setAgreedToTerms(bool val) {
    _agreedToTerms = val;
    notifyListeners();
  }

  void setSubmitting(bool val) {
    _isSubmitting = val;
    notifyListeners();
  }

  void setErrorMessage(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  bool get isEmailValid {
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(_email);
  }

  bool get isPasswordLengthValid => _password.length >= 8;
  bool get hasPasswordNumber => _password.contains(RegExp(r'[0-9]'));
  bool get hasPasswordSpecialOrUpper =>
      _password.contains(RegExp(r'[A-Z]')) ||
      _password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  bool get isPasswordValid =>
      isPasswordLengthValid && hasPasswordNumber && hasPasswordSpecialOrUpper;

  bool get isAccountFormValid =>
      isEmailValid && isPasswordValid && _agreedToTerms;

  /// Resets all values back to clean default state
  void reset() {
    _language = AppLanguage.english;
    _name = '';
    _birthDate = null;
    _gender = null;
    _customGender = '';
    _selectedPurposes.clear();
    _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
    _breakfastTime = const TimeOfDay(hour: 8, minute: 30);
    _lunchTime = const TimeOfDay(hour: 13, minute: 0);
    _dinnerTime = const TimeOfDay(hour: 20, minute: 0);
    _bedtimeTime = const TimeOfDay(hour: 22, minute: 30);
    _isRoutineFlexible = false;
    _wantsCareCircle = false;
    _contactName = '';
    _countryCode = '+1';
    _phoneNumber = '';
    _relationship = null;
    _alertDelayMinutes = 30;
    _agreedToShareAlerts = false;
    _email = '';
    _password = '';
    _agreedToTerms = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}
