import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';

import '../support/medicine_fakes.dart';

void main() {
  late MemoryMedicineStore store;
  late FakeNotifications notifications;
  late MedicineReminderProvider provider;
  late DateTime now;
  setUp(() async {
    now = DateTime(2026, 10, 17, 10);
    store = MemoryMedicineStore();
    notifications = FakeNotifications();
    provider = MedicineReminderProvider(
      store: store,
      notifications: notifications,
      clock: () => now,
    );
    provider.bindUser('alice');
    await provider.ready;
  });
  tearDown(() => provider.dispose());

  test(
    'starts empty and restores account-scoped records after restart',
    () async {
      expect(provider.medications, isEmpty);
      expect(await provider.addMedication(testMedication()), isTrue);
      final restarted = MedicineReminderProvider(
        store: store,
        notifications: FakeNotifications(),
        clock: () => now,
      );
      restarted.bindUser('alice');
      await restarted.ready;
      expect(restarted.medications.single.name, 'Test medicine');
      expect(restarted.todayDoses, hasLength(2));
      restarted.dispose();
    },
  );
  test('taken applies to one dated dose and never to tomorrow', () async {
    await provider.addMedication(testMedication());
    final first = provider.todayDoses.first;
    await provider.act(first, DoseAction.taken);
    expect(provider.takenCount, 1);
    expect(provider.todayDoses.last.isTaken, isFalse);
    now = now.add(const Duration(days: 1));
    expect(provider.takenCount, 0);
    expect(provider.totalCount, 2);
  });
  test(
    'double taps and notification retries create one effective completion',
    () async {
      await provider.addMedication(testMedication());
      final dose = provider.todayDoses.first;
      await Future.wait([
        provider.act(dose, DoseAction.taken),
        provider.act(dose, DoseAction.taken),
      ]);
      expect(provider.events, hasLength(1));
      await provider.act(
        dose,
        DoseAction.taken,
        requestId: 'notification-retry',
      );
      expect(provider.events, hasLength(1));
      expect(notifications.canceled, contains(dose.id));
    },
  );
  test(
    'skip and undo keep an action trail without affecting another dose',
    () async {
      await provider.addMedication(testMedication());
      final dose = provider.todayDoses.first;
      await provider.act(dose, DoseAction.skipped);
      expect(provider.skippedCount, 1);
      expect(provider.pendingCount, 1);
      await provider.act(dose, DoseAction.undo);
      expect(provider.skippedCount, 0);
      expect(provider.pendingCount, 2);
      expect(provider.events.map((e) => e.action), [
        DoseAction.skipped,
        DoseAction.undo,
      ]);
    },
  );
  test('snooze moves only the alert and completion cancels it', () async {
    await provider.addMedication(testMedication());
    final dose = provider.todayDoses.first;
    await provider.act(dose, DoseAction.snooze);
    final snoozed = provider.todayDoses.first;
    expect(snoozed.dueAt, dose.dueAt);
    expect(snoozed.alertAt, now.add(const Duration(minutes: 15)));
    expect(provider.todayDoses, hasLength(2));
    await provider.act(snoozed, DoseAction.taken);
    expect(provider.todayDoses.first.isTaken, isTrue);
  });
  test('write failure preserves visible and durable state', () async {
    await provider.addMedication(testMedication());
    store.failWrites = true;
    expect(
      await provider.act(provider.todayDoses.first, DoseAction.taken),
      isFalse,
    );
    expect(provider.takenCount, 0);
    expect(provider.events, isEmpty);
    expect((await store.load('alice')).events, isEmpty);
    expect(provider.errorMessage, isNotNull);
  });
  test(
    'scheduler failure keeps successful records and exposes recovery status',
    () async {
      notifications.failScheduling = true;
      expect(await provider.addMedication(testMedication()), isTrue);
      expect(provider.medications, hasLength(1));
      expect(provider.readiness.error, isNotNull);
      notifications.failScheduling = false;
      await provider.refresh();
      expect(provider.readiness.error, isNull);
    },
  );
  test(
    'account switch hides records immediately and logout cancels reminders',
    () async {
      await provider.addMedication(testMedication());
      provider.bindUser('bob');
      expect(provider.medications, isEmpty);
      await provider.ready;
      expect(provider.medications, isEmpty);
      expect(notifications.lastOwner, 'bob');
      provider.bindUser('alice');
      await provider.ready;
      expect(provider.medications, hasLength(1));
      provider.bindUser(null);
      expect(provider.medications, isEmpty);
      await provider.ready;
      expect(notifications.lastOwner, isNull);
      expect(notifications.clears, greaterThanOrEqualTo(4));
    },
  );
  test('queued old-account mutation cannot leak into new account', () async {
    final save = provider.addMedication(testMedication());
    provider.bindUser('bob');
    expect(await save, isFalse);
    await provider.ready;
    expect((await store.load('bob')).medications, isEmpty);
  });
  test(
    'deleted and paused notification actions cannot recreate records',
    () async {
      final medicine = testMedication();
      await provider.addMedication(medicine);
      final dose = provider.todayDoses.first;
      await provider.setPaused(medicine, true);
      notifications.intent.value = ReminderIntent(
        'alice',
        dose.id,
        dose.dueAt,
        'taken',
      );
      await Future<void>.delayed(Duration.zero);
      expect(provider.events, isEmpty);
      expect(provider.errorMessage, contains('no longer active'));
      await provider.deleteMedication(medicine.id);
      expect(await provider.act(dose, DoseAction.taken), isFalse);
      expect(provider.medications, isEmpty);
      expect(provider.events, isEmpty);
    },
  );
  test('next scheduled dose retains simultaneous medicines', () async {
    await provider.addMedication(testMedication());
    await provider.addMedication(
      testMedication(id: 'med-2', name: 'Another medicine'),
    );
    expect(provider.nextDoses, hasLength(2));
  });
  test('search and filters use dose state', () async {
    await provider.addMedication(testMedication());
    await provider.act(provider.todayDoses.first, DoseAction.taken);
    provider.setFilter(MedicineFilter.taken);
    expect(provider.filteredDoses, hasLength(1));
    provider.setSearchQuery('500 MG');
    expect(provider.filteredDoses, hasLength(1));
    provider.setSearchQuery('absent');
    expect(provider.filteredDoses, isEmpty);
  });
  test('invalid quantities never reach storage', () async {
    expect(await provider.addMedication(testMedication(amount: '0')), isFalse);
    expect(
      await provider.addMedication(testMedication(amount: '500 mg')),
      isFalse,
    );
    expect(provider.medications, isEmpty);
  });
  test('notification from another owner is rejected', () async {
    await provider.addMedication(testMedication());
    final dose = provider.todayDoses.first;
    notifications.intent.value = ReminderIntent(
      'bob',
      dose.id,
      dose.dueAt,
      'taken',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.events, isEmpty);
    expect(provider.errorMessage, contains('another account'));
  });
  test(
    'notification initialization failure does not hide saved medicines',
    () async {
      await provider.addMedication(testMedication());
      notifications.failInitialization = true;
      notifications.failScheduling = true;
      provider.bindUser('bob');
      await provider.ready;
      provider.bindUser('alice');
      await provider.ready;
      expect(provider.medications, hasLength(1));
      expect(provider.errorMessage, isNull);
      expect(provider.readiness.error, isNotNull);
    },
  );
  test(
    'future courses beyond the alarm horizon still have a next-dose summary',
    () async {
      await provider.addMedication(
        testMedication(start: DateTime(2027, 2, 1), times: [480]),
      );
      expect(provider.todayDoses, isEmpty);
      expect(
        provider.nextDoses.single.dueAt.toUtc(),
        DateTime.utc(2027, 2, 1, 2, 30),
      );
    },
  );
  test('snoozing an upcoming dose never brings its alert earlier', () async {
    await provider.addMedication(testMedication());
    final upcoming = provider.todayDoses.last;
    await provider.act(upcoming, DoseAction.snooze);
    expect(
      provider.todayDoses.last.alertAt,
      upcoming.dueAt.add(const Duration(minutes: 15)),
    );
  });
  test(
    'replayed snooze notifications are idempotent after correction',
    () async {
      await provider.addMedication(testMedication());
      final dose = provider.todayDoses.first;
      final intent = ReminderIntent(
        'alice',
        dose.id,
        dose.dueAt,
        'snooze',
        alertKey: 'original-alert',
      );
      notifications.intent.value = intent;
      await Future<void>.delayed(Duration.zero);
      expect(provider.events, hasLength(1));
      notifications.intent.value = intent;
      await Future<void>.delayed(Duration.zero);
      expect(provider.events, hasLength(1));
      await provider.act(dose, DoseAction.undo);
      notifications.intent.value = intent;
      await Future<void>.delayed(Duration.zero);
      expect(provider.events, hasLength(2));
      expect(provider.events.last.action, DoseAction.undo);
    },
  );
}
