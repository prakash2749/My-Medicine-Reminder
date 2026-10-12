import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/models/medicine_reminder_model.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';

void main() {
  group('MedicineReminderProvider', () {
    late MedicineReminderProvider provider;

    setUp(() {
      provider = MedicineReminderProvider();
    });

    test('initializes with sample reminders and correct counts', () {
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.totalCount, 3);
      expect(provider.currentFilter, MedicineFilter.all);

      // Default sample has 1 taken and 2 pending
      expect(provider.takenCount, 1);
      expect(provider.pendingCount, 2);
      expect(provider.adherenceRate, closeTo(1 / 3, 0.01));
    });

    test('addReminder inserts new reminder at the top of the list', () {
      final newReminder = MedicineReminder(
        id: 'new-1',
        name: 'Aspirin',
        dosage: '100 mg',
        time: '09:00 AM',
        createdAt: DateTime.now(),
      );

      provider.addReminder(newReminder);

      expect(provider.totalCount, 4);
      expect(provider.allReminders.first.id, 'new-1');
      expect(provider.allReminders.first.name, 'Aspirin');
    });

    test('updateReminder updates an existing reminder by id', () {
      final initialFirst = provider.allReminders.first;
      final updated = initialFirst.copyWith(notes: 'Updated note for test');

      provider.updateReminder(updated);

      final found = provider.allReminders.firstWhere(
        (r) => r.id == initialFirst.id,
      );
      expect(found.notes, 'Updated note for test');
    });

    test('deleteReminder removes item from list', () {
      final initialCount = provider.totalCount;
      provider.deleteReminder('1');

      expect(provider.totalCount, initialCount - 1);
      expect(provider.allReminders.any((r) => r.id == '1'), isFalse);
    });

    test(
      'toggleTaken flips isTaken flag and updates adherence calculation',
      () {
        // Reminder '2' is initially isTaken = false
        final reminder2 = provider.allReminders.firstWhere((r) => r.id == '2');
        expect(reminder2.isTaken, isFalse);
        final initialTakenCount = provider.takenCount;

        provider.toggleTaken('2');

        final toggled = provider.allReminders.firstWhere((r) => r.id == '2');
        expect(toggled.isTaken, isTrue);
        expect(provider.takenCount, initialTakenCount + 1);

        // Toggle back to false
        provider.toggleTaken('2');
        expect(
          provider.allReminders.firstWhere((r) => r.id == '2').isTaken,
          isFalse,
        );
        expect(provider.takenCount, initialTakenCount);
      },
    );

    test('setFilter correctly filters by all, pending, and taken', () {
      provider.setFilter(MedicineFilter.taken);
      expect(provider.filteredReminders.every((r) => r.isTaken), isTrue);

      provider.setFilter(MedicineFilter.pending);
      expect(provider.filteredReminders.every((r) => !r.isTaken), isTrue);

      provider.setFilter(MedicineFilter.all);
      expect(provider.filteredReminders.length, provider.totalCount);
    });

    test('setSearchQuery filters reminders matching name or dosage case-insensitively', () {
      provider.setSearchQuery('amox');
      expect(provider.filteredReminders.length, 1);
      expect(provider.filteredReminders.first.name, 'Amoxicillin');

      provider.setSearchQuery('850 mg');
      expect(provider.filteredReminders.length, 1);
      expect(provider.filteredReminders.first.name, 'Metformin');

      provider.setSearchQuery('non-existent-medicine');
      expect(provider.filteredReminders, isEmpty);

      provider.setSearchQuery('');
      expect(provider.filteredReminders.length, provider.totalCount);
    });

    test('clearError resets errorMessage to null', () {
      // By default null
      expect(provider.errorMessage, isNull);
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });
  });
}
