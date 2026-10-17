import 'dart:convert';

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
  Medication draft({
    String name = 'Original',
    String amount = '1',
    List<int> times = const [480, 1200],
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
    DateTime? end,
    int? revision,
  }) =>
      testMedication(
        name: name,
        amount: amount,
        zone: 'Asia/Kolkata',
        times: times,
        days: days,
        end: end,
      ).copyWith(
        revision: revision ?? provider.medications.firstOrNull?.revision ?? 1,
      );
  Future<MedicineData> saved() => store.load('alice');
  List<DoseOccurrence> alarms(MedicineData data) => data
      .doses(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 3)),
        remindersOnly: true,
      )
      .where((d) => !d.isComplete && d.alertAt.isAfter(now))
      .toList();

  setUp(() async {
    now = DateTime.utc(2026, 10, 17, 4, 30);
    store = MemoryMedicineStore();
    notifications = FakeNotifications();
    provider = MedicineReminderProvider(
      store: store,
      notifications: notifications,
      clock: () => now,
    );
    provider.bindUser('alice');
    await provider.ready;
    await provider.addMedication(draft());
  });
  tearDown(() => provider.dispose());

  test(
    'edit owns future instants and keeps old descriptions and action trails',
    () async {
      final morning = provider.todayDoses.first;
      await provider.act(morning, DoseAction.taken);
      expect(
        await provider.editMedication(
          draft(name: 'Updated', amount: '0.5', times: [540, 1260]),
        ),
        isTrue,
      );
      final data = await saved();
      expect(data.previousRevisions.single.effectiveUntil, now);
      expect(data.medications.single.effectiveFrom, now);
      expect(data.medications.single.revision, 2);
      expect(provider.todayDoses.map((d) => d.medication.name), [
        'Original',
        'Updated',
      ]);
      expect(provider.todayDoses.first.id, morning.id);
      expect(provider.todayDoses.first.isTaken, isTrue);
      expect(provider.todayDoses.first.medication.amount, '1');
      expect(
        provider.todayDoses.last.dueAt,
        DateTime.utc(2026, 10, 17, 15, 30),
      );
      expect(provider.events, hasLength(1));
      expect(alarms(data).every((d) => d.medication.revision == 2), isTrue);
    },
  );

  test(
    'edit during snooze cancels old alert while keeping past dose record',
    () async {
      final morning = provider.todayDoses.first;
      await provider.act(morning, DoseAction.snooze);
      expect(alarms(await saved()).any((d) => d.id == morning.id), isTrue);
      await provider.editMedication(draft(times: [660]));
      expect(alarms(await saved()).any((d) => d.id == morning.id), isFalse);
      expect(provider.todayDoses.first.remindersAllowed, isFalse);
      expect(await provider.act(morning, DoseAction.snooze), isFalse);
      expect(await provider.act(morning, DoseAction.taken), isTrue);
      expect(provider.todayDoses.first.isTaken, isTrue);
    },
  );

  test(
    'future obsolete snooze is hidden from Today but retained in audit records',
    () async {
      final evening = provider.todayDoses.last;
      await provider.act(evening, DoseAction.snooze);
      await provider.editMedication(draft(times: [1260]));
      expect(provider.todayDoses.any((d) => d.id == evening.id), isFalse);
      expect(
        provider.recordedHistory(evening.medication.id).single.id,
        evening.id,
      );
      expect(alarms(await saved()).any((d) => d.id == evening.id), isFalse);
    },
  );

  test(
    'early confirmation claims its original slot across edits and undo',
    () async {
      final evening = provider.todayDoses.last;
      await provider.act(evening, DoseAction.taken);
      await provider.editMedication(draft(name: 'Renamed', amount: '2'));
      final retained = provider.todayDoses.last;
      expect(retained.id, evening.id);
      expect(retained.medication.name, 'Original');
      expect(
        provider.todayDoses.where((d) => d.dueAt == evening.dueAt),
        hasLength(1),
      );
      expect(
        alarms(await saved()).any((d) => d.dueAt == evening.dueAt),
        isFalse,
      );
      expect(await provider.act(retained, DoseAction.undo), isTrue);
      expect(provider.todayDoses.last.status(now), 'Canceled');
      expect(provider.pendingCount, 1);
      expect(await provider.act(retained, DoseAction.snooze), isFalse);
      expect(
        alarms(await saved()).any((d) => d.dueAt == evening.dueAt),
        isFalse,
      );
      now = DateTime.utc(2026, 10, 17, 15);
      expect(provider.todayDoses.last.status(now), 'Canceled');
      expect(await provider.act(retained, DoseAction.taken), isFalse);
    },
  );

  test(
      'end date shortening removes future doses, clearing it restores future dates',
      () async {
    await provider.editMedication(draft(end: DateTime(2026, 10, 16)));
    expect(
      provider.todayDoses,
      hasLength(1),
    ); // Earlier morning belongs to original version.
    expect(alarms(await saved()), isEmpty);
    await provider.editMedication(
      draft(),
    ); // Explicit null end date from the editor.
    expect(provider.medications.single.endsOn, isNull);
    expect(alarms(await saved()), isNotEmpty);
  });

  test(
    'weekday edit removes remaining doses today without rewriting morning',
    () async {
      await provider.editMedication(draft(days: [DateTime.sunday]));
      expect(provider.todayDoses, hasLength(1));
      expect(provider.nextDoses.first.dueAt, DateTime.utc(2026, 10, 18, 2, 30));
    },
  );

  test('effective boundary belongs to exactly one schedule revision', () async {
    now = DateTime.utc(2026, 10, 17, 14, 30);
    await provider.editMedication(draft(name: 'At boundary'));
    final doses = provider.todayDoses.where((d) => d.dueAt == now).toList();
    expect(doses, hasLength(1));
    expect(doses.single.medication.revision, 2);
  });

  test(
    'pause and resume preserve records and do not restore gap or old snoozes',
    () async {
      await provider.act(provider.todayDoses.first, DoseAction.snooze);
      await provider.setPaused(provider.medications.single, true);
      expect(alarms(await saved()), isEmpty);
      now = DateTime.utc(2026, 10, 18, 4, 30);
      expect(provider.todayDoses, isEmpty);
      await provider.setPaused(provider.medications.single, false);
      expect(provider.todayDoses, hasLength(1));
      expect(
        provider.todayDoses.single.dueAt,
        DateTime.utc(2026, 10, 18, 14, 30),
      );
      expect(
        alarms(await saved()).every((d) => d.alertAt.isAfter(now)),
        isTrue,
      );
      expect(provider.recordedHistory('med-1'), hasLength(1));
    },
  );

  test(
    'editing paused medicine preserves pause and resume uses newest details',
    () async {
      await provider.setPaused(provider.medications.single, true);
      await provider.editMedication(draft(name: 'While paused', times: [1260]));
      expect(provider.medications.single.paused, isTrue);
      expect(alarms(await saved()), isEmpty);
      await provider.setPaused(provider.medications.single, false);
      expect(provider.nextDoses.single.medication.name, 'While paused');
      expect(
        provider.nextDoses.single.dueAt,
        DateTime.utc(2026, 10, 17, 15, 30),
      );
    },
  );

  test(
    'archive is idempotent, read-only, durable and preserves original records',
    () async {
      await provider.act(provider.todayDoses.first, DoseAction.skipped);
      await provider.act(provider.todayDoses.last, DoseAction.snooze);
      final original = provider.medications.single;
      expect(await provider.archiveMedication(original), isTrue);
      expect(await provider.archiveMedication(original), isTrue);
      expect((await saved()).previousRevisions, hasLength(1));
      expect(await provider.editMedication(draft()), isFalse);
      expect(
        await provider.setPaused(provider.medications.single, false),
        isFalse,
      );
      expect(alarms(await saved()), isEmpty);
      final decoded = MedicineData.decode(jsonEncode((await saved()).toJson()));
      expect(decoded.medications.single.archived, isTrue);
      expect(decoded.recordedDoses, hasLength(2));
      expect(decoded.events, hasLength(2));
      expect(decoded.previousRevisions.single.name, 'Original');
      expect(provider.recordedHistory('med-1').last.isSkipped, isTrue);
      expect(provider.todayDoses, hasLength(1));
    },
  );

  test(
    'rapid stale edits cannot overwrite the committed latest version',
    () async {
      final results = await Future.wait([
        provider.editMedication(draft(name: 'First', revision: 1)),
        provider.editMedication(draft(name: 'Stale', revision: 1)),
      ]);
      expect(results, [true, false]);
      expect(provider.errorMessage, contains('Reopen'));
      expect(provider.medications.single.name, 'First');
      expect((await saved()).previousRevisions, hasLength(1));
      expect(await provider.editMedication(draft(name: 'Fresh')), isTrue);
      expect(provider.medications.single.revision, 3);
      expect((await saved()).previousRevisions.map((m) => m.revision), [1, 2]);
    },
  );

  test(
    'failed edit/archive writes preserve plan, records and reminder input',
    () async {
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      final before = jsonEncode((await saved()).toJson());
      store.failWrites = true;
      expect(await provider.editMedication(draft(name: 'Not saved')), isFalse);
      expect(
        await provider.archiveMedication(provider.medications.single),
        isFalse,
      );
      expect(jsonEncode((await saved()).toJson()), before);
      expect(jsonEncode(notifications.lastData.toJson()), before);
      expect(provider.medications.single.name, 'Original');
    },
  );

  test(
    'scheduler failure after edit keeps committed version and retry repairs it',
    () async {
      notifications.failScheduling = true;
      expect(await provider.editMedication(draft(name: 'Saved')), isTrue);
      expect(provider.readiness.error, isNotNull);
      expect((await saved()).medications.single.name, 'Saved');
      notifications.failScheduling = false;
      await provider.refresh();
      expect(provider.readiness.error, isNull);
      expect(notifications.lastData.medications.single.revision, 2);
    },
  );

  test(
    'old notification intent after edit cannot create completion or snooze',
    () async {
      final old = provider.todayDoses.first;
      await provider.editMedication(draft());
      for (final action in ['taken', 'snooze']) {
        notifications.intent.value = ReminderIntent(
          'alice',
          old.id,
          old.dueAt,
          action,
        );
        await Future<void>.delayed(Duration.zero);
        expect(provider.events, isEmpty);
        expect(provider.errorMessage, contains('no longer active'));
      }
    },
  );

  test(
    'notification action queued behind an edit is rechecked at commit',
    () async {
      final old = provider.todayDoses.first;
      final edit = provider.editMedication(draft(name: 'Changed'));
      final notificationAction = provider.act(
        old,
        DoseAction.taken,
        requireActive: true,
      );
      expect(await edit, isTrue);
      expect(await notificationAction, isFalse);
      expect(provider.events, isEmpty);
      expect(await provider.act(old, DoseAction.taken), isTrue);
    },
  );

  test('queued edit cannot cross account boundary', () async {
    final edit = provider.editMedication(draft(name: 'Wrong account'));
    provider.bindUser('bob');
    expect(await edit, isFalse);
    await provider.ready;
    expect((await store.load('bob')).medications, isEmpty);
    expect((await saved()).medications.single.name, 'Original');
  });

  test('backward clock cannot invert revision bounds', () async {
    await provider.editMedication(draft(name: 'First'));
    now = now.subtract(const Duration(hours: 1));
    expect(await provider.editMedication(draft(name: 'Inverted')), isFalse);
    expect(provider.errorMessage, contains('clock'));
    expect((await saved()).previousRevisions, hasLength(1));
  });

  test(
    'delete removes all revisions, snapshots and events for only that medicine',
    () async {
      await provider.addMedication(testMedication(id: 'other'));
      await provider.act(
        provider.todayDoses.firstWhere((d) => d.medication.id == 'med-1'),
        DoseAction.taken,
      );
      await provider.editMedication(draft(name: 'Changed'));
      await provider.archiveMedication(
        provider.medications.firstWhere((m) => m.id == 'med-1'),
      );
      await provider.deleteMedication('med-1');
      final data = await saved();
      expect(data.medications.single.id, 'other');
      expect(data.events, isEmpty);
      expect(data.previousRevisions, isEmpty);
      expect(data.recordedDoses, isEmpty);
    },
  );

  test(
      'version 1 migrates original confirmations and snoozes, then round-trips v2',
      () async {
    final evening = provider.todayDoses.last;
    await provider.act(evening, DoseAction.taken);
    await provider.act(provider.todayDoses.first, DoseAction.snooze);
    final raw = (await saved()).toJson()
      ..['version'] = 1
      ..remove('previousRevisions')
      ..remove('recordedDoses');
    final migrated = MedicineData.decode(jsonEncode(raw));
    expect(migrated.recordedDoses, hasLength(2));
    expect(migrated.recordedDoses.first.medication.amount, '1');
    expect(migrated.events, hasLength(2));
    final roundTrip = MedicineData.decode(jsonEncode(migrated.toJson()));
    expect(
      roundTrip.recordedDoses.map((d) => d.id),
      migrated.recordedDoses.map((d) => d.id),
    );
    await store.change('alice', (_) => migrated);
    await provider.refresh();
    await provider.editMedication(draft(name: 'After migration'));
    expect(provider.todayDoses.last.id, evening.id);
    expect(provider.todayDoses.last.medication.name, 'Original');
    expect(alarms(await saved()).any((d) => d.dueAt == evening.dueAt), isFalse);
  });
}
