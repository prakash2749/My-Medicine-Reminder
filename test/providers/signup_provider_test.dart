import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/constants/app_language.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';

void main() {
  group('SignupProvider Tests', () {
    late SignupProvider provider;

    setUp(() {
      provider = SignupProvider();
    });

    test('Initial state is empty and default', () {
      expect(provider.name, isEmpty);
      expect(provider.birthDate, isNull);
      expect(provider.gender, isNull);
      expect(provider.isPersonalInfoValid, isFalse);
      expect(provider.selectedPurposes, isEmpty);
      expect(provider.isRoutineFlexible, isFalse);
      expect(provider.wantsCareCircle, isFalse);
      expect(provider.isCareCircleValid, isTrue); // optional
      expect(provider.isAccountFormValid, isFalse);
      expect(provider.language, AppLanguage.english);
    });

    test('AppLanguage enum values and parsing', () {
      expect(AppLanguage.values.length, 3);
      expect(AppLanguage.values, [
        AppLanguage.english,
        AppLanguage.gujarati,
        AppLanguage.hindi,
      ]);

      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('gu'), AppLanguage.gujarati);
      expect(AppLanguage.fromCode('hi'), AppLanguage.hindi);

      provider.setLanguage(AppLanguage.gujarati);
      expect(provider.language, AppLanguage.gujarati);

      provider.setLanguage(AppLanguage.hindi);
      expect(provider.language, AppLanguage.hindi);
    });

    test('Personal info updates and validates', () {
      provider.setName('Jane Doe');
      expect(provider.name, 'Jane Doe');
      expect(provider.isPersonalInfoValid, isFalse); // birthDate still null

      provider.setBirthDate(DateTime(1995, 5, 20));
      expect(provider.isPersonalInfoValid, isTrue);

      provider.setGender('Female');
      expect(provider.gender, 'Female');
      expect(SignupProvider.availableGenders, ['Female', 'Male']);
    });

    test('Purpose toggling works correctly', () {
      const purpose = 'Get medication reminders';
      provider.togglePurpose(purpose);
      expect(provider.selectedPurposes.contains(purpose), isTrue);

      provider.togglePurpose(purpose);
      expect(provider.selectedPurposes.contains(purpose), isFalse);

      provider.togglePurpose(purpose);
      provider.togglePurpose('Track whether I took my meds');
      expect(provider.selectedPurposes.length, 2);

      provider.clearPurposes();
      expect(provider.selectedPurposes, isEmpty);
    });

    test('My Day routine updates', () {
      provider.setWakeUpTime(const TimeOfDay(hour: 6, minute: 30));
      expect(provider.wakeUpTime, const TimeOfDay(hour: 6, minute: 30));

      provider.setIsRoutineFlexible(true);
      expect(provider.isRoutineFlexible, isTrue);
    });

    test('Care Circle validation works when enabled', () {
      provider.setWantsCareCircle(true);
      expect(provider.isCareCircleValid, isFalse);

      provider.setContactName('Dr. Sarah');
      provider.setPhoneNumber('555-1234');
      provider.setRelationship('Caregiver');
      expect(provider.isCareCircleValid, isFalse); // agreement not checked

      provider.setAgreedToShareAlerts(true);
      expect(provider.isCareCircleValid, isTrue);
    });

    test('Account credentials validation requirements', () {
      provider.setEmail('invalid-email');
      expect(provider.isEmailValid, isFalse);

      provider.setEmail('user@notify.app');
      expect(provider.isEmailValid, isTrue);

      provider.setPassword('short');
      expect(provider.isPasswordLengthValid, isFalse);

      provider.setPassword('password');
      expect(provider.hasPasswordNumber, isFalse);

      provider.setPassword('Password123!');
      expect(provider.isPasswordValid, isTrue);

      expect(provider.isAccountFormValid, isFalse); // terms not checked

      provider.setAgreedToTerms(true);
      expect(provider.isAccountFormValid, isTrue);
    });

    test('Reset restores initial defaults', () {
      provider.setName('Jane');
      provider.setEmail('jane@example.com');
      provider.setWantsCareCircle(true);

      provider.reset();
      expect(provider.name, isEmpty);
      expect(provider.email, isEmpty);
      expect(provider.wantsCareCircle, isFalse);
    });
  });
}
