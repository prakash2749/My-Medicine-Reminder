import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';
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

  /// Saves the complete onboarding setup into Supabase database tables.
  Future<bool> saveOnboardingProfile({
    required String userId,
    required SignupProvider signupData,
    String timezone = 'Asia/Kolkata',
  }) async {
    final supabase = client;
    if (supabase == null) {
      debugPrint('Supabase client unavailable, skipping onboarding database sync.');
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
        'gender': signupData.gender, // 'Male' or 'Female' (matches public.gender_type)
        'language': signupData.language.displayName, // 'English', 'Gujarati', 'Hindi'
        'timezone': timezone,
        'onboarding_step': 'completed',
        'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Insert/Update public.routine_times (My Day schedule)
      final routineRows = [
        {
          'user_id': userId,
          'event_type': 'wake_up',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(signupData.wakeUpTime),
        },
        {
          'user_id': userId,
          'event_type': 'breakfast',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(signupData.breakfastTime),
        },
        {
          'user_id': userId,
          'event_type': 'lunch',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(signupData.lunchTime),
        },
        {
          'user_id': userId,
          'event_type': 'dinner',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(signupData.dinnerTime),
        },
        {
          'user_id': userId,
          'event_type': 'bedtime',
          'local_time': DateTimeUtils.formatTimeOfDayToSql(signupData.bedtimeTime),
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
              final match = questionsList.cast<Map<String, dynamic>>().firstWhere(
                    (q) =>
                        q['question_text'] == selectedText ||
                        _matchesQuestionCode(q['code'] as String?, selectedText),
                    orElse: () => <String, dynamic>{},
                  );

              if (match.isNotEmpty && match['id'] != null) {
                await supabase.from('onboarding_answers').upsert(
                  {
                    'user_id': userId,
                    'question_id': match['id'],
                  },
                  onConflict: 'user_id,question_id',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Error syncing onboarding_answers: $e');
        }
      }

      // 4. Insert into public.care_circle_members if invited
      if (signupData.wantsCareCircle && signupData.phoneNumber.isNotEmpty) {
        try {
          final phoneE164 = PhoneUtils.formatE164(
            signupData.countryCode,
            signupData.phoneNumber,
          );
          await supabase.from('care_circle_members').upsert(
            {
              'user_id': userId,
              'contact_name': signupData.contactName,
              'phone_e164': phoneE164,
              'relationship': signupData.relationship,
              'alert_delay_minutes': signupData.alertDelayMinutes,
              'alerts_enabled': true,
              'share_medication_details': false,
              'owner_consented_at': DateTime.now().toUtc().toIso8601String(),
              'status': 'pending',
            },
            onConflict: 'user_id,phone_e164',
          );
        } catch (e) {
          debugPrint('Error syncing care_circle_members: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('OnboardingService.saveOnboardingProfile failed: $e');
      return false;
    }
  }

  /// Updates existing profile fields (e.g., changing preferred language or details)
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    final supabase = client;
    if (supabase == null) return false;

    try {
      await supabase.from('profiles').update(updates).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('OnboardingService.updateProfile error: $e');
      return false;
    }
  }

  /// Fetches the user profile from Supabase
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final res = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
      return res;
    } catch (e) {
      debugPrint('OnboardingService.getProfile error: $e');
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
