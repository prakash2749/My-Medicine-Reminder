import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/models/medicine_reminder_model.dart';

void main() {
  group('MedicineReminder Model', () {
    final sampleDate = DateTime(2026, 1, 15, 8, 30);
    final sampleReminder = MedicineReminder(
      id: 'rem-101',
      name: 'Amoxicillin',
      dosage: '500 mg',
      time: '08:00 AM',
      frequency: 'Twice daily',
      category: 'Capsule',
      notes: 'Take with food',
      isTaken: true,
      createdAt: sampleDate,
    );

    test('toJson produces correct map structure', () {
      final json = sampleReminder.toJson();

      expect(json['id'], 'rem-101');
      expect(json['name'], 'Amoxicillin');
      expect(json['dosage'], '500 mg');
      expect(json['time'], '08:00 AM');
      expect(json['frequency'], 'Twice daily');
      expect(json['category'], 'Capsule');
      expect(json['notes'], 'Take with food');
      expect(json['is_taken'], isTrue);
      expect(json['created_at'], sampleDate.toIso8601String());
    });

    test('fromJson parses full JSON object properly', () {
      final json = {
        'id': 'rem-102',
        'name': 'Ibuprofen',
        'dosage': '400 mg',
        'time': '02:00 PM',
        'frequency': 'As needed',
        'category': 'Pill',
        'notes': 'Take after meal',
        'is_taken': false,
        'created_at': sampleDate.toIso8601String(),
      };

      final reminder = MedicineReminder.fromJson(json);

      expect(reminder.id, 'rem-102');
      expect(reminder.name, 'Ibuprofen');
      expect(reminder.dosage, '400 mg');
      expect(reminder.time, '02:00 PM');
      expect(reminder.frequency, 'As needed');
      expect(reminder.category, 'Pill');
      expect(reminder.notes, 'Take after meal');
      expect(reminder.isTaken, isFalse);
      expect(reminder.createdAt, sampleDate);
    });

    test(
      'fromJson handles fallback defaults when optional fields are null',
      () {
        final minimalJson = {'id': 'rem-minimal', 'name': 'Vitamin C'};

        final reminder = MedicineReminder.fromJson(minimalJson);

        expect(reminder.id, 'rem-minimal');
        expect(reminder.name, 'Vitamin C');
        expect(reminder.dosage, '');
        expect(reminder.time, '08:00 AM');
        expect(reminder.frequency, 'Daily');
        expect(reminder.category, 'Pill');
        expect(reminder.notes, isNull);
        expect(reminder.isTaken, isFalse);
        expect(reminder.createdAt, isA<DateTime>());
      },
    );

    test('copyWith updates specified fields only', () {
      final updated = sampleReminder.copyWith(
        name: 'Amoxicillin Forte',
        isTaken: false,
      );

      expect(updated.id, sampleReminder.id);
      expect(updated.name, 'Amoxicillin Forte');
      expect(updated.dosage, sampleReminder.dosage);
      expect(updated.time, sampleReminder.time);
      expect(updated.isTaken, isFalse);
      expect(updated.createdAt, sampleReminder.createdAt);
    });
  });
}
