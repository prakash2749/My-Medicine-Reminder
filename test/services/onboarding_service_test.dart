import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/utils/date_time_utils.dart';
import 'package:medicine_reminder/core/utils/phone_utils.dart';

void main() {
  group('DateTimeUtils Tests', () {
    test('formatTimeOfDayToSql formats TimeOfDay to SQL HH:mm:00', () {
      expect(
        DateTimeUtils.formatTimeOfDayToSql(const TimeOfDay(hour: 7, minute: 0)),
        '07:00:00',
      );
      expect(
        DateTimeUtils.formatTimeOfDayToSql(
          const TimeOfDay(hour: 8, minute: 30),
        ),
        '08:30:00',
      );
      expect(
        DateTimeUtils.formatTimeOfDayToSql(
          const TimeOfDay(hour: 22, minute: 45),
        ),
        '22:45:00',
      );
    });

    test('formatTimeOfDayTo12Hour formats TimeOfDay to 12-hour AM/PM', () {
      expect(
        DateTimeUtils.formatTimeOfDayTo12Hour(
          const TimeOfDay(hour: 7, minute: 0),
        ),
        '7:00 AM',
      );
      expect(
        DateTimeUtils.formatTimeOfDayTo12Hour(
          const TimeOfDay(hour: 13, minute: 30),
        ),
        '1:30 PM',
      );
      expect(
        DateTimeUtils.formatTimeOfDayTo12Hour(
          const TimeOfDay(hour: 0, minute: 15),
        ),
        '12:15 AM',
      );
    });

    test('formatDateToDisplay formats DateTime to DD Mon YYYY', () {
      expect(
        DateTimeUtils.formatDateToDisplay(DateTime(2000, 11, 9)),
        '09 Nov 2000',
      );
      expect(
        DateTimeUtils.formatDateToDisplay(DateTime(1995, 5, 20)),
        '20 May 1995',
      );
    });

    test('formatDateToSql formats DateTime to YYYY-MM-DD', () {
      expect(
        DateTimeUtils.formatDateToSql(DateTime(2026, 10, 12)),
        '2026-10-12',
      );
    });
  });

  group('PhoneUtils Tests', () {
    test('formatE164 formats phone numbers with country code', () {
      expect(PhoneUtils.formatE164('+1', '555-123-4567'), '+15551234567');
      expect(PhoneUtils.formatE164('+91', '98765 43210'), '+919876543210');
      expect(PhoneUtils.formatE164('+1', '+15559876543'), '+15559876543');
    });

    test('isValidE164 validates phone pattern', () {
      expect(PhoneUtils.isValidE164('+15551234567'), isTrue);
      expect(PhoneUtils.isValidE164('+919876543210'), isTrue);
      expect(PhoneUtils.isValidE164('5551234567'), isFalse);
    });
  });
}
