import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';

import '../support/medicine_fakes.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const engine = ScheduleEngine();
  test('Android timezone aliases produce the same India dose instants', () {
    final alias = testMedication(zone: 'Asia/Calcutta');
    alias.validate();
    final start = DateTime.utc(2026, 10, 17);
    final end = DateTime.utc(2026, 10, 18);
    expect(
      engine.generate([alias], [], start, end).map((d) => d.dueAt),
      engine.generate([testMedication()], [], start, end).map((d) => d.dueAt),
    );
  });
  test('selected weekdays and inclusive date boundaries use plan timezone', () {
    final plan = testMedication(
      start: DateTime(2026, 10, 16),
      end: DateTime(2026, 10, 19),
      days: [1, 6],
      times: [0, 1439],
    );
    final result = engine.generate(
      [plan],
      [],
      DateTime.utc(2026, 10, 15),
      DateTime.utc(2026, 10, 21),
    );
    expect(result, hasLength(4)); // Saturday and Monday, two times each.
    expect(result.first.dueAt.toUtc(), DateTime.utc(2026, 10, 16, 18, 30));
    expect(result.last.dueAt.toUtc(), DateTime.utc(2026, 10, 19, 18, 29));
  });
  test('leap day and year boundaries are generated without duplicate IDs', () {
    final plan = testMedication(start: DateTime(2024), times: [480, 1200]);
    final result = engine.generate(
      [plan],
      [],
      DateTime.utc(2024, 2, 28),
      DateTime.utc(2024, 3, 1),
    );
    expect(result, hasLength(4));
    expect(result.any((d) => d.id.contains('2024-02-29')), isTrue);
    final again = engine.generate(
      [plan],
      [],
      DateTime.utc(2024, 2, 28),
      DateTime.utc(2024, 3, 1),
    );
    expect(again.map((d) => d.id), result.map((d) => d.id));
    expect(result.map((d) => d.id).toSet(), hasLength(4));
    final year = engine.generate(
      [plan],
      [],
      DateTime.utc(2026, 12, 31),
      DateTime.utc(2027, 1, 2),
    );
    expect(year, hasLength(4));
  });
  test(
    'DST calendar recurrence retains clock time instead of adding 24 hours',
    () {
      final plan = testMedication(
        zone: 'America/New_York',
        start: DateTime(2026, 3, 7),
        times: [480],
      );
      final doses = engine.generate(
        [plan],
        [],
        DateTime.utc(2026, 3, 7),
        DateTime.utc(2026, 3, 10),
      );
      expect(doses, hasLength(3));
      expect(
        doses[1].dueAt.difference(doses[0].dueAt),
        const Duration(hours: 23),
      );
      expect(
        tz.TZDateTime.from(doses[1].dueAt, tz.getLocation(plan.timezone)).hour,
        8,
      );
    },
  );
  test('DST gap shifts forward and autumn fold produces one occurrence', () {
    final spring = testMedication(
      zone: 'America/New_York',
      start: DateTime(2026, 3, 8),
      times: [150],
    );
    final gap = engine.generate(
      [spring],
      [],
      DateTime.utc(2026, 3, 8),
      DateTime.utc(2026, 3, 9),
    );
    expect(gap, hasLength(1));
    expect(gap.single.dueAt, DateTime.utc(2026, 3, 8, 7));
    expect(
      tz.TZDateTime.from(
        gap.single.dueAt,
        tz.getLocation(spring.timezone),
      ).hour,
      3,
    );
    final autumn = testMedication(
      zone: 'America/New_York',
      start: DateTime(2026, 11, 1),
      times: [90],
    );
    expect(
      engine.generate(
        [autumn],
        [],
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 2),
      ),
      hasLength(1),
    );
  });
  test(
      'half-hour DST gap moves to first valid minute and date skips do not duplicate',
      () {
    final lordHowe = testMedication(
        zone: 'Australia/Lord_Howe',
        start: DateTime(2026, 10, 4),
        times: [135]);
    final gap = engine.generate([lordHowe], [], DateTime.utc(2026, 10, 3, 12),
        DateTime.utc(2026, 10, 4, 12));
    expect(gap, hasLength(1));
    final local =
        tz.TZDateTime.from(gap.single.dueAt, tz.getLocation(lordHowe.timezone));
    expect(local.hour * 60 + local.minute, 150);
    final apia = testMedication(
        zone: 'Pacific/Apia', start: DateTime(2011, 12, 29), times: [480]);
    final skipped = engine.generate(
        [apia], [], DateTime.utc(2011, 12, 29), DateTime.utc(2012, 1, 1));
    expect(skipped.any((dose) => dose.id.contains('2011-12-30')), isFalse);
    expect(skipped.map((dose) => dose.dueAt).toSet().length, skipped.length);
  });
  test(
      'decimal amounts and unicode round-trip without confusing strength with quantity',
      () {
    final medicine = testMedication(name: 'दवा', amount: '0.50');
    final data = MedicineData(
      medications: [medicine],
      events: [
        DoseEvent(
          id: 'e',
          occurrenceId: 'd',
          action: DoseAction.snooze,
          recordedAt: DateTime.utc(2026),
          snoozedUntil: DateTime.utc(2026, 1, 1, 0, 15),
        ),
      ],
    );
    final restored = MedicineData.decode(jsonEncode(data.toJson()));
    expect(restored.medications.single.name, 'दवा');
    expect(restored.medications.single.amount, '0.50');
    expect(restored.medications.single.strength, '500 mg');
    expect(restored.events.single.action, DoseAction.snooze);
  });
  test('unknown storage schema is rejected without reinterpretation', () {
    expect(() => MedicineData.decode('{"version":999}'), throwsFormatException);
  });
  test('duplicate times, no weekdays and reversed dates are rejected', () {
    expect(
      () => testMedication(times: [480, 480]).validate(),
      throwsFormatException,
    );
    expect(() => testMedication(days: []).validate(), throwsFormatException);
    expect(
      () => testMedication(
        start: DateTime(2026, 10, 20),
        end: DateTime(2026, 10, 19),
      ).validate(),
      throwsFormatException,
    );
  });
}
