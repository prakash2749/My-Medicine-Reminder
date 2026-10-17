import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/models/reminder_context.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/core/services/reminder_recovery.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';

import '../support/medicine_fakes.dart';

class _RefillNotifications extends FakeNotifications {
  @override
  Future<ReminderReadiness> sync(
    String? owner,
    MedicineData data,
    DateTime now, {
    bool forceRebuild = false,
  }) async =>
      ReminderReadiness(
        supported: true,
        notifications: true,
        exact: true,
        refillAlertsSent: data.stockAccounts
            .where(
              (s) =>
                  s.active &&
                  data.balance(s.id) <= s.threshold &&
                  s.alertedEpisode != s.episode,
            )
            .map((s) => s.id)
            .toList(),
      );
}

void main() {
  late MemoryMedicineStore store;
  late FakeNotifications notifications;
  late MedicineReminderProvider provider;
  late DateTime now;
  late int elapsed, boot, generation;
  late String zone;
  setUp(() async {
    now = DateTime.utc(2026, 10, 17, 4, 30);
    elapsed = 1000000;
    boot = 5;
    generation = 1;
    zone = 'Asia/Kolkata';
    store = MemoryMedicineStore();
    notifications = FakeNotifications();
    provider = MedicineReminderProvider(
      store: store,
      notifications: notifications,
      clock: () => now,
      recoveryProbe: () async => ReminderContext(
        timezone: zone,
        wallTime: now,
        elapsedMillis: elapsed,
        bootCount: boot,
        generation: generation,
      ),
    );
    provider.bindUser('alice');
    await provider.ready;
    await provider.addMedication(testMedication());
  });
  tearDown(() => provider.dispose());

  test('unchanged environment keeps native scheduling idempotent', () async {
    now = now.add(const Duration(minutes: 1));
    elapsed += 60000;
    await provider.refresh();
    expect(notifications.lastForceRebuild, isFalse);
    expect(provider.lastReminderCheckAt, now);
  });
  test(
    'forward and backward clock adjustments force repair without confirmations',
    () async {
      for (final shift in [
        const Duration(hours: 2),
        const Duration(hours: -3),
      ]) {
        now = now.add(shift);
        elapsed += 1000;
        await provider.refresh();
        expect(notifications.lastForceRebuild, isTrue);
        expect(provider.events, isEmpty);
      }
    },
  );
  test('boot and system recovery generations force replacement', () async {
    boot++;
    elapsed = 1000;
    await provider.refresh();
    expect(notifications.lastForceRebuild, isTrue);
    generation++;
    await provider.refresh();
    expect(notifications.lastForceRebuild, isTrue);
    await provider.refresh();
    expect(notifications.lastForceRebuild, isFalse);
  });
  test(
      'travel preserves schedule zone, explains verification, and acknowledgement persists',
      () async {
    zone = 'America/New_York';
    await provider.refresh();
    expect(
      provider.travelNotice,
      contains('Verify medicine timing with your clinician'),
    );
    expect(provider.medications.single.timezone, 'Asia/Kolkata');
    await provider.acknowledgeTimezone();
    expect(provider.travelNotice, isNull);
    provider.bindUser('bob');
    await provider.ready;
    provider.bindUser('alice');
    await provider.ready;
    expect(provider.travelNotice, isNull);
    zone = 'Europe/London';
    await provider.refresh();
    expect(provider.travelNotice, isNotNull);
  });
  test(
    'equivalent India timezone alias does not create a travel warning',
    () async {
      zone = 'Asia/Calcutta';
      await provider.refresh();
      expect(provider.travelNotice, isNull);
    },
  );
  test(
    'repair never changes dose confirmations, versions, or inventory',
    () async {
      await provider.startStock(
        provider.medications.single,
        '5',
        '1',
        requestId: 'initial',
      );
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      final before = (await store.load('alice')).toJson()
        ..remove('reminderContext');
      generation++;
      now = now.add(const Duration(hours: 1));
      await provider.refresh();
      final after = (await store.load('alice')).toJson()
        ..remove('reminderContext');
      expect(jsonEncode(after), jsonEncode(before));
    },
  );
  test(
    'paused and archived plans never regain future alerts on recovery',
    () async {
      await provider.setPaused(provider.medications.single, true);
      generation++;
      await provider.refresh();
      expect(provider.nextDoses, isEmpty);
      await provider.archiveMedication(provider.medications.single);
      generation++;
      await provider.refresh();
      expect(provider.nextDoses, isEmpty);
      expect(provider.events, isEmpty);
    },
  );
  test('scheduling failure keeps context eligible for retry', () async {
    final before = (await store.load('alice')).reminderContext!;
    notifications.failScheduling = true;
    generation++;
    await provider.refresh();
    expect(provider.readiness.error, isNotNull);
    expect(
      (await store.load('alice')).reminderContext!.generation,
      before.generation,
    );
    notifications.failScheduling = false;
    await provider.refresh();
    expect(provider.readiness.error, isNull);
    expect(notifications.lastForceRebuild, isTrue);
  });
  test(
      'successful refill notice acknowledgement is durable and replenishment resets it',
      () async {
    await provider.startStock(
      provider.medications.single,
      '1',
      '2',
      requestId: 'initial',
    );
    final service = _RefillNotifications();
    await reconcileReminders(store, service, now, forceRebuild: true);
    var account = (await store.load('alice')).stockFor('med-1')!;
    expect(account.alertedEpisode, account.episode);
    final next = await reconcileReminders(
      store,
      service,
      now,
      forceRebuild: true,
    );
    expect(next.readiness.refillAlertsSent, isEmpty);
    await provider.refresh();
    account = provider.stockFor('med-1')!;
    await provider.updateStock(
      account,
      quantity: '0.1',
      refill: true,
      requestId: 'refill',
    );
    final result = await reconcileReminders(store, service, now);
    expect(result.readiness.refillAlertsSent, [account.id]);
  });
  test('refill taps validate owner before focusing stock', () async {
    await provider.startStock(
      provider.medications.single,
      '5',
      '1',
      requestId: 'initial',
    );
    notifications.intent.value = ReminderIntent(
      'bob',
      '',
      now,
      null,
      refillMedicineId: 'med-1',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.focusedRefill, isNull);
    notifications.intent.value = ReminderIntent(
      'alice',
      '',
      now,
      null,
      refillMedicineId: 'med-1',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.focusedRefill, 'med-1');
    expect(provider.events, isEmpty);
  });
}
