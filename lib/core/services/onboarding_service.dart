import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';

import '../models/onboarding_question_model.dart';
import '../utils/date_time_utils.dart';
import '../utils/phone_utils.dart';
import 'supabase_service.dart';

/// Service responsible for inserting & updating Supabase MVP tables:
/// - profiles
/// - routine_times
/// - onboarding_questions & onboarding_answers
/// - care_circle_members
class OnboardingService {
  final SupabaseClient? _customClient;

  OnboardingService({SupabaseClient? client}) : _customClient = client;

  SupabaseClient? get client => _customClient ?? SupabaseService.client;

  /// Default seed questions matching public.onboarding_questions table
  static const List<OnboardingQuestion> defaultQuestions = [
    OnboardingQuestion(
      id: 'b1854e8c-43c1-4c6d-a54e-d9965c301111',
      code: 'medicine_reminders',
      questionText: 'Remember my medicines',
      displayOrder: 1,
    ),
    OnboardingQuestion(
      id: 'de3eed8c-4228-459a-9687-79b17e632222',
      code: 'dose_history',
      questionText: 'Track doses I have taken',
      displayOrder: 2,
    ),
    OnboardingQuestion(
      id: '53368d19-85e3-404d-9411-d0c5ce8e3333',
      code: 'refill_reminders',
      questionText: 'Know when to refill',
      displayOrder: 3,
    ),
    OnboardingQuestion(
      id: 'c8cceb61-4a9c-4fef-9f13-7bfdd12b4444',
      code: 'prescription_organization',
      questionText: 'Organize prescriptions',
      displayOrder: 4,
    ),
    OnboardingQuestion(
      id: '2beea6d4-5c3a-4697-989f-2eacfa2c5555',
      code: 'family_support',
      questionText: 'Get family support',
      displayOrder: 5,
    ),
  ];

  /// Fetches active onboarding purpose questions dynamically from the public.onboarding_questions table.
  Future<List<OnboardingQuestion>> fetchOnboardingQuestions() async {
    final supabase = client;
    if (supabase == null) {
      return defaultQuestions;
    }

    try {
      final response = await supabase
          .from('onboarding_questions')
          .select('id, code, question_text, display_order, is_active')
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> data = response;
      if (data.isEmpty) return defaultQuestions;
      return data
          .map(
            (item) => OnboardingQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching onboarding questions from Supabase.');
      return defaultQuestions;
    }
  }

  /// Saves the complete onboarding setup into Supabase database tables.
  Future<bool> saveOnboardingProfile({
    required String userId,
    required SignupProvider signupData,
    String timezone = 'Asia/Kolkata',
  }) async {
    final supabase = client;
    if (supabase == null) {
      debugPrint(
        'Supabase client unavailable, skipping onboarding database sync.',
      );
      return false;
    }

    try {
      // 1. Insert/Update public.profiles
      final birthDateStr = signupData.birthDate != null
          ? DateTimeUtils.formatDateToSql(signupData.birthDate!)
          : null;

      await supabase.from('profiles').upsert({
        'id': userId,
        'name': signupData.name.isNotEmpty ? signupData.name : null,
        'birth_date': birthDateStr,
        'gender': signupData
            .gender, // 'Male' or 'Female' (matches public.gender_type)
        'language':
            signupData.language.displayName, // 'English', 'Gujarati', 'Hindi'
        'timezone': timezone,
        'onboarding_step': 'completed',
        'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Insert/Update public.routine_times (My Day schedule)
      final routineRows = [
        {
          'user_id': userId,
          'event_type': 'wake_up',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(
            signupData.wakeUpTime,
          ),
        },
        {
          'user_id': userId,
          'event_type': 'breakfast',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(
            signupData.breakfastTime,
          ),
        },
        {
          'user_id': userId,
          'event_type': 'lunch',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(
            signupData.lunchTime,
          ),
        },
        {
          'user_id': userId,
          'event_type': 'dinner',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(
            signupData.dinnerTime,
          ),
        },
        {
          'user_id': userId,
          'event_type': 'bedtime',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(
            signupData.bedtimeTime,
          ),
        },
      ];

      for (final row in routineRows) {
        await supabase
            .from('routine_times')
            .upsert(row, onConflict: 'user_id,event_type');
      }

      // 3. Insert/Update public.onboarding_answers (Purpose selections)
      if (signupData.selectedPurposes.isNotEmpty) {
        try {
          // Fetch existing active questions from master table
          final questionsResponse = await supabase
              .from('onboarding_questions')
              .select('id, question_text, code')
              .eq('is_active', true);

          final List<dynamic> questionsList = questionsResponse;
          if (questionsList.isNotEmpty) {
            for (final selectedText in signupData.selectedPurposes) {
              // Match by question text or code
              final match =
                  questionsList.cast<Map<String, dynamic>>().firstWhere(
                        (q) =>
                            q['question_text'] == selectedText ||
                            _matchesQuestionCode(
                              q['code'] as String?,
                              selectedText,
                            ),
                        orElse: () => <String, dynamic>{},
                      );

              if (match.isNotEmpty && match['id'] != null) {
                await supabase.from('onboarding_answers').upsert({
                  'user_id': userId,
                  'question_id': match['id'],
                }, onConflict: 'user_id,question_id');
              }
            }
          }
        } catch (e) {
          debugPrint('Error syncing onboarding_answers.');
        }
      }

      // 4. Insert into public.care_circle_members if invited
      if (signupData.wantsCareCircle && signupData.phoneNumber.isNotEmpty) {
        try {
          final phoneE164 = PhoneUtils.formatE164(
            signupData.countryCode,
            signupData.phoneNumber,
          );
          await supabase.from('care_circle_members').upsert({
            'user_id': userId,
            'contact_name': signupData.contactName,
            'phone_e164': phoneE164,
            'relationship': signupData.relationship,
            'alert_delay_minutes': signupData.alertDelayMinutes,
            'alerts_enabled': true,
            'share_medication_details': false,
            'owner_consented_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'pending',
          }, onConflict: 'user_id,phone_e164');
        } catch (e) {
          debugPrint('Error syncing care_circle_members.');
        }
      }

      return true;
    } catch (e) {
      debugPrint('OnboardingService.saveOnboardingProfile failed.');
      return false;
    }
  }

  /// Updates existing profile fields (e.g., changing preferred language or details)
  Future<bool> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final supabase = client;
    if (supabase == null) return false;

    try {
      await supabase.from('profiles').update(updates).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('OnboardingService.updateProfile error.');
      return false;
    }
  }

  /// Fetches the user profile from Supabase
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('OnboardingService.getProfile error.');
      return null;
    }
  }

  /// Fuzzy matcher between app purpose strings and database question codes
  static bool _matchesQuestionCode(String? code, String text) {
    if (code == null) return false;
    switch (code) {
      case 'medicine_reminders':
        return text.contains('reminder') || text.contains('Remind');
      case 'dose_history':
        return text.contains('took') || text.contains('doses');
      case 'refill_reminders':
        return text.contains('refill');
      case 'prescription_organization':
        return text.contains('list') || text.contains('prescription');
      case 'family_support':
        return text.contains('family') || text.contains('support');
      default:
        return false;
    }
  }
}
