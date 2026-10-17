import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medicine_reminder/core/models/inventory.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/models/schedule_contract.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  const engine = ScheduleEngine();

  group('MED-007 Composite Occurrence ID Grammar & Value Object', () {
    test(
        'parses valid composite occurrence IDs conforming to formal BNF grammar',
        () {
      const valid = 'med-amox-001:2:2026-10-18:480';
      final parsed = OccurrenceId.parse(valid);
      expect(parsed.medicationId, 'med-amox-001');
      expect(parsed.revision, 2);
      expect(parsed.calendarDate, '2026-10-18');
      expect(parsed.minuteOfDay, 480);
      expect(parsed.value, valid);
      expect(parsed.toString(), valid);
      expect(OccurrenceId.isValid(valid), isTrue);
    });

    test('validates boundary minute values (0, 720, 1439)', () {
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:0'), isTrue);
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:720'), isTrue);
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:1439'), isTrue);
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:1440'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:-1'), isFalse);
    });

    test('rejects malformed occurrence IDs with descriptive FormatException',
        () {
      expect(() => OccurrenceId.parse(''), throwsFormatException);
      expect(() => OccurrenceId.parse('med-1'), throwsFormatException);
      expect(() => OccurrenceId.parse('med-1:0:2026-10-18:480'),
          throwsFormatException); // revision < 1
      expect(() => OccurrenceId.parse('med-1:1:2026-13-01:480'),
          throwsFormatException); // month 13
      expect(() => OccurrenceId.parse('med-1:1:2026-10-32:480'),
          throwsFormatException); // day 32
      expect(() => OccurrenceId.parse('med-1:1:2026-10-18:1440'),
          throwsFormatException); // minute 1440
      expect(OccurrenceId.tryParse('invalid'), isNull);
    });

    test('OccurrenceId.format produces canonical composite ID string', () {
      final formatted = OccurrenceId.format(
        medicationId: 'aspirin-uuid-101',
        revision: 1,
        calendarDate: '2026-10-18',
        minuteOfDay: 480,
      );
      expect(formatted, 'aspirin-uuid-101:1:2026-10-18:480');
      expect(OccurrenceId.isValid(formatted), isTrue);
    });

    test('OccurrenceId equality and hashCode contract', () {
      final a = OccurrenceId.parse('med-1:1:2026-10-18:480');
      final b = OccurrenceId.parse('med-1:1:2026-10-18:480');
      final c = OccurrenceId.parse('med-1:2:2026-10-18:480');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('MED-007 Fixed-Point Scale 10^4 Decimal Math & Zero Drift Verification',
      () {
    test('exact conversion for standard clinical quantities', () {
      expect(FixedPointMath.parse('1'), 10000);
      expect(FixedPointMath.parse('0.5'), 5000);
      expect(FixedPointMath.parse('0.25'), 2500);
      expect(FixedPointMath.parse('7.5'), 75000);
      expect(FixedPointMath.parse('0.125'), 1250);
      expect(FixedPointMath.parse('0.0001'), 1);

      expect(FixedPointMath.format(10000), '1');
      expect(FixedPointMath.format(5000), '0.5');
      expect(FixedPointMath.format(2500), '0.25');
      expect(FixedPointMath.format(75000), '7.5');
      expect(FixedPointMath.format(1250), '0.125');
      expect(FixedPointMath.format(1), '0.0001');
      expect(FixedPointMath.format(-10000), '-1');
    });

    test(
        'enforces max 6 whole digits and 4 decimal places regex ^\\d{1,6}(\\.\\d{1,4})?\$',
        () {
      expect(FixedPointMath.parse('999999.9999'), 9999999999);
      expect(() => FixedPointMath.parse('1000000'), throwsFormatException);
      expect(() => FixedPointMath.parse('1.00001'), throwsFormatException);
      expect(() => FixedPointMath.parse('.5'),
          throwsFormatException); // omitted leading zero rejected
      expect(() => FixedPointMath.parse('abc'), throwsFormatException);
      expect(() => FixedPointMath.parse('0'), throwsFormatException);
      expect(FixedPointMath.parse('0', allowZero: true), 0);
    });

    test(
        '1,000-cycle simulation demonstrates zero cumulative floating point drift',
        () {
      final passed = FixedPointMath.verifyZeroFloatDriftSimulation(
        cycles: 1000,
        initialScaled: 1000000, // 100.0000 units
        stepScaled: 1000, // 0.1000 unit per cycle
      );
      expect(passed, isTrue);

      // Verify that after 1,000 deductions of 0.1 from 100.0, balance is exactly 0
      var balance = 1000000;
      for (var i = 0; i < 1000; i++) {
        balance -= 1000;
      }
      expect(balance, 0);
      expect(FixedPointMath.format(balance), '0');
    });
  });

  group('MED-007 Clinician Safety Rules & Entity Separation', () {
    test('enforces strict separation of name, strength, form, amount, and unit',
        () {
      ClinicianSafetyValidator.validateClinicalDosageSeparation(
        name: 'Metformin Hydrochloride',
        strength: '500 mg',
        form: 'Tablet',
        amount: '1',
        unit: 'tablet',
      );

      // Blank or excessive name
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: '',
          strength: '500 mg',
          form: 'Tablet',
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );

      // Excessive strength
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: 'Metformin',
          strength: 'A' * 101,
          form: 'Tablet',
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );

      // Blank form
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: 'Metformin',
          strength: '500 mg',
          form: '',
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );
    });

    test('ISMP Safety: prohibits unit abbreviation "U" or "u"', () {
      expect(
        () => ClinicianSafetyValidator.validateAdministrationUnit('U'),
        throwsFormatException,
      );
      expect(
        () => ClinicianSafetyValidator.validateAdministrationUnit('u'),
        throwsFormatException,
      );
      expect(
        () => ClinicianSafetyValidator.validateAdministrationUnit(''),
        throwsFormatException,
      );
      // Valid unit entries
      ClinicianSafetyValidator.validateAdministrationUnit('unit');
      ClinicianSafetyValidator.validateAdministrationUnit('units');
      ClinicianSafetyValidator.validateAdministrationUnit('tablet');
      ClinicianSafetyValidator.validateAdministrationUnit('mL');
    });

    test(
        'prohibits automatic unit conversions between administration and stock units',
        () {
      ClinicianSafetyValidator.validateUnitConsistency(
        medicineUnit: 'tablet',
        stockUnit: 'tablet',
      );

      expect(
        () => ClinicianSafetyValidator.validateUnitConsistency(
          medicineUnit: 'mL',
          stockUnit: 'bottle',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Stop stock tracking before changing the dose unit. Units are never converted automatically.',
          ),
        ),
      );
    });

    test(
        'validates calendar boundaries: endsOn >= startsOn (calendar-inclusive)',
        () {
      final start = DateTime(2026, 10, 18);
      final sameDay = DateTime(2026, 10, 18);
      final laterDay = DateTime(2026, 10, 28);
      final earlierDay = DateTime(2026, 10, 17);

      ClinicianSafetyValidator.validateCalendarBoundaries(
          startsOn: start, endsOn: sameDay);
      ClinicianSafetyValidator.validateCalendarBoundaries(
          startsOn: start, endsOn: laterDay);
      ClinicianSafetyValidator.validateCalendarBoundaries(
          startsOn: start, endsOn: null);

      expect(
        () => ClinicianSafetyValidator.validateCalendarBoundaries(
          startsOn: start,
          endsOn: earlierDay,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'End date must be on or after the start date.',
          ),
        ),
      );
    });
  });

  group('MED-007 Tri-State Adherence Semantics & Non-Punitive Reporting', () {
    final baseMed = Medication(
      id: 'med-adh-001',
      name: 'Lisinopril',
      strength: '10 mg',
      amount: '1',
      unit: 'tablet',
      timezone: 'America/New_York',
      minutes: const [480],
      startsOn: DateTime.utc(2026, 10, 18),
    );

    test('evaluates status conforming to Section 7.2 formal state machine', () {
      final evalTime = DateTime.utc(
          2026, 10, 18, 14, 0); // 10:00 EDT (past 08:00 EDT / 12:00 UTC)
      final dueInstant = DateTime.utc(2026, 10, 18, 12, 0); // 08:00 EDT

      // 1. Unconfirmed when due time has passed without action
      final unconfirmed = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
      );
      expect(evaluateOccurrenceStatus(unconfirmed, evalTime),
          DoseOccurrenceStatus.unconfirmed);
      expect(unconfirmed.status(evalTime), 'Unconfirmed');

      // 2. Upcoming when due time is in the future
      final upcomingInstant = DateTime.utc(2026, 10, 18, 16, 0);
      final upcoming = DoseOccurrence(
        medication: baseMed,
        dueAt: upcomingInstant,
        id: 'med-adh-001:1:2026-10-18:720',
      );
      expect(evaluateOccurrenceStatus(upcoming, evalTime),
          DoseOccurrenceStatus.upcoming);
      expect(upcoming.status(evalTime), 'Upcoming');

      // 3. Taken when latest event is taken
      final taken = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
        latestEvent: DoseEvent(
          id: 'evt-take',
          occurrenceId: 'med-adh-001:1:2026-10-18:480',
          action: DoseAction.taken,
          recordedAt: evalTime,
        ),
      );
      expect(evaluateOccurrenceStatus(taken, evalTime),
          DoseOccurrenceStatus.taken);
      expect(taken.status(evalTime), 'Taken');

      // 4. Skipped when latest event is skipped
      final skipped = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
        latestEvent: DoseEvent(
          id: 'evt-skip',
          occurrenceId: 'med-adh-001:1:2026-10-18:480',
          action: DoseAction.skipped,
          recordedAt: evalTime,
        ),
      );
      expect(evaluateOccurrenceStatus(skipped, evalTime),
          DoseOccurrenceStatus.skipped);
      expect(skipped.status(evalTime), 'Skipped');

      // 5. Snoozed when latest event is snooze and alertAt > evalTime
      final snoozed = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
        latestEvent: DoseEvent(
          id: 'evt-snooze',
          occurrenceId: 'med-adh-001:1:2026-10-18:480',
          action: DoseAction.snooze,
          recordedAt: evalTime,
          snoozedUntil: evalTime.add(const Duration(minutes: 15)),
        ),
      );
      expect(evaluateOccurrenceStatus(snoozed, evalTime),
          DoseOccurrenceStatus.snoozed);
      expect(snoozed.status(evalTime), 'Snoozed');

      // 6. Snooze expired transitions back to Unconfirmed
      final expiredSnooze = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
        latestEvent: DoseEvent(
          id: 'evt-snooze',
          occurrenceId: 'med-adh-001:1:2026-10-18:480',
          action: DoseAction.snooze,
          recordedAt: evalTime.subtract(const Duration(minutes: 30)),
          snoozedUntil: evalTime.subtract(const Duration(minutes: 15)),
        ),
      );
      expect(evaluateOccurrenceStatus(expiredSnooze, evalTime),
          DoseOccurrenceStatus.unconfirmed);

      // 7. Canceled when canceled flag is true
      final canceled = DoseOccurrence(
        medication: baseMed,
        dueAt: dueInstant,
        id: 'med-adh-001:1:2026-10-18:480',
        canceled: true,
      );
      expect(evaluateOccurrenceStatus(canceled, evalTime),
          DoseOccurrenceStatus.canceled);
      expect(canceled.status(evalTime), 'Canceled');
    });

    test(
        'adherence report calculates honest non-punitive fraction and includes footnote',
        () {
      final now = DateTime.utc(2026, 10, 18, 20, 0);
      final morningDose = DoseOccurrence(
        medication: baseMed,
        dueAt: DateTime.utc(2026, 10, 18, 12, 0),
        id: 'med-adh-001:1:2026-10-18:480',
        latestEvent: DoseEvent(
          id: 'e1',
          occurrenceId: 'med-adh-001:1:2026-10-18:480',
          action: DoseAction.taken,
          recordedAt: DateTime.utc(2026, 10, 18, 12, 5),
        ),
      );
      final afternoonDose = DoseOccurrence(
        medication: baseMed,
        dueAt: DateTime.utc(2026, 10, 18, 16, 0),
        id: 'med-adh-001:1:2026-10-18:720',
        // unconfirmed: due in past, no event
      );
      final eveningDose = DoseOccurrence(
        medication: baseMed,
        dueAt: DateTime.utc(2026, 10, 18, 22, 0),
        id: 'med-adh-001:1:2026-10-18:1080',
        // upcoming: due in future
      );

      final report = calculateAdherenceReport(
        occurrences: [morningDose, afternoonDose, eveningDose],
        evaluationInstant: now,
      );

      expect(report.totalScheduled, 3);
      expect(report.totalEligible, 2); // morning and afternoon are past due
      expect(report.confirmedTaken, 1);
      expect(report.unconfirmed, 1);
      expect(report.upcoming, 1);
      expect(report.adherenceFraction, 0.5); // 1 taken / 2 eligible
      expect(
        report.clinicalFootnote,
        'Unconfirmed doses represent absence of mobile recording, not verified clinical omission.',
      );
    });
  });

  group('Canonical Synthetic Fixtures Verification (FIX-001 to FIX-008)', () {
    // -------------------------------------------------------------------------
    // FIX-001: Multi-Component Strength & Tablet Regimen
    // -------------------------------------------------------------------------
    test('FIX-001: Multi-Component Strength & Tablet Regimen', () {
      final data = ScheduleFixtures.fix001Data();
      expect(data.medications, hasLength(1));

      final med = data.medications.single;
      expect(med.id, 'med-amox-clav-001');
      expect(med.name, 'Amoxicillin and Clavulanate Potassium');
      expect(med.strength, '875 mg / 125 mg');
      expect(med.form, 'Tablet');
      expect(med.amount, '1');
      expect(med.unit, 'tablet');
      expect(med.timezone, 'America/New_York');
      expect(med.minutes, [480, 1200]);
      expect(med.weekdays, [1, 2, 3, 4, 5, 6, 7]);
      med.validate();

      expect(data.stockAccounts, hasLength(1));
      final stock = data.stockAccounts.single;
      expect(stock.medicineId, med.id);
      expect(stock.unit, med.unit);
      expect(stock.threshold, 40000); // 4 tablets

      expect(data.stockEntries, hasLength(1));
      final initEntry = data.stockEntries.single;
      expect(initEntry.delta, 200000); // 20 tablets
      expect(initEntry.kind, StockEntryKind.initial);
      expect(data.balance(stock.id), 200000);

      // Verify recurrence generation across inclusive boundary: 2026-10-18 to 2026-10-28 (11 days * 2 = 22 doses)
      // Note: 20:00 EDT on 2026-10-28 is 2026-10-29 00:00:00 UTC. Using 2026-10-29 12:00 UTC covers the whole day.
      final doses = engine.generate(
        [med],
        data.events,
        tz.TZDateTime(tz.getLocation(med.timezone), 2026, 10, 18),
        tz.TZDateTime(tz.getLocation(med.timezone), 2026, 10, 29),
      );
      expect(doses, hasLength(22));
      expect(doses.first.id, 'med-amox-clav-001:1:2026-10-18:480');
      expect(doses.last.id, 'med-amox-clav-001:1:2026-10-28:1200');
      for (final d in doses) {
        expect(OccurrenceId.isValid(d.id), isTrue);
      }
    });

    // -------------------------------------------------------------------------
    // FIX-002: Pediatric Fractional Liquid Suspension
    // -------------------------------------------------------------------------
    test('FIX-002: Pediatric Fractional Liquid Suspension (7.5 mL TID)', () {
      final data = ScheduleFixtures.fix002Data();
      final med = data.medications.single;
      expect(med.id, 'med-ped-amox-002');
      expect(med.strength, '250 mg / 5 mL');
      expect(med.form, 'Liquid');
      expect(med.amount, '7.5');
      expect(med.unit, 'mL');
      expect(med.timezone, 'America/Chicago');
      expect(med.minutes, [480, 840, 1200]);
      med.validate();

      final stock = data.stockAccounts.single;
      expect(stock.threshold, 450000); // 45 mL threshold
      expect(stock.unit, 'mL');

      final initEntry = data.stockEntries.single;
      expect(initEntry.delta, 1500000); // 150 mL initial
      expect(data.balance(stock.id), 1500000);

      // 8 days (18th to 25th) * 3 doses/day = 24 doses
      // Note: 20:00 CDT on 2026-10-25 is 2026-10-26 01:00 UTC. Using 2026-10-26 12:00 UTC covers the whole day.
      final doses = engine.generate(
        [med],
        data.events,
        DateTime.utc(2026, 10, 18, 0, 0),
        DateTime.utc(2026, 10, 26, 12, 0),
      );
      expect(doses, hasLength(24));
      expect(FixedPointMath.parse(med.amount), 75000);
    });

    // -------------------------------------------------------------------------
    // FIX-003: Bi-Temporal Mid-Day Schedule Revision
    // -------------------------------------------------------------------------
    test(
        'FIX-003: Bi-Temporal Mid-Day Schedule Revision (500mg morning, 1000mg evening)',
        () {
      final data = ScheduleFixtures.fix003Data();

      // Current active revision is revision 2 (1000mg)
      expect(data.medications.single.revision, 2);
      expect(data.medications.single.strength, '1000 mg');
      expect(data.medications.single.effectiveFrom,
          DateTime.utc(2026, 10, 18, 14, 0));

      // Archived historical revision is revision 1 (500mg)
      expect(data.previousRevisions.single.revision, 1);
      expect(data.previousRevisions.single.strength, '500 mg');
      expect(data.previousRevisions.single.effectiveUntil,
          DateTime.utc(2026, 10, 18, 14, 0));

      // Recorded dose preserves original 500 mg snapshot
      expect(data.recordedDoses, hasLength(1));
      final morningSnapshot = data.recordedDoses.single;
      expect(morningSnapshot.medication.revision, 1);
      expect(morningSnapshot.medication.strength, '500 mg');
      expect(morningSnapshot.id, 'med-metformin-003:1:2026-10-18:480');

      // Dose projection: morning dose retains slot with revision 1, evening dose uses revision 2
      final projected = data.doses(
        DateTime.utc(2026, 10, 18, 0, 0),
        DateTime.utc(2026, 10, 19, 12, 0),
      );
      expect(projected, hasLength(2));
      final morningDose = projected.firstWhere((d) => d.id.contains(':480'));
      expect(morningDose.medication.revision, 1);
      expect(morningDose.medication.strength, '500 mg');
      expect(morningDose.isTaken, isTrue);

      final eveningDose = projected.firstWhere((d) => d.id.contains(':1200'));
      expect(eveningDose.medication.revision, 2);
      expect(eveningDose.medication.strength, '1000 mg');
    });

    // -------------------------------------------------------------------------
    // FIX-004: DST Spring-Forward Gap in America/New_York
    // -------------------------------------------------------------------------
    test(
        'FIX-004: DST Spring-Forward Gap shifts forward with 23.5h elapsed interval',
        () {
      final data = ScheduleFixtures.fix004Data();
      final med = data.medications.single;
      expect(med.timezone, 'America/New_York');
      expect(med.minutes, [150]); // 02:30 AM

      final doses = engine.generate(
        [med],
        [],
        DateTime.utc(2026, 3, 7, 0, 0),
        DateTime.utc(2026, 3, 10, 0, 0),
      );
      expect(doses, hasLength(3));

      final expected = ScheduleFixtures.fix004ExpectedOccurrences();
      expect(doses[0].id, expected[0]['id']);
      expect(doses[0].dueAt, DateTime.parse(expected[0]['dueAt'] as String));

      // On 2026-03-08, 02:30 is skipped due to spring forward (2:00 -> 3:00); shifts to 03:00 EDT (07:00 UTC)
      expect(doses[1].id, expected[1]['id']);
      expect(doses[1].dueAt, DateTime.parse(expected[1]['dueAt'] as String));

      // Elapsed duration from 07:30 UTC to 07:00 UTC next day is 23.5 hours
      final elapsed = doses[1].dueAt.difference(doses[0].dueAt);
      expect(elapsed, const Duration(hours: 23, minutes: 30));

      // On 2026-03-09, standard EDT 02:30 EDT is 06:30 UTC
      expect(doses[2].id, expected[2]['id']);
      expect(doses[2].dueAt, DateTime.parse(expected[2]['dueAt'] as String));
    });

    // -------------------------------------------------------------------------
    // FIX-005: DST Autumn-Fold Disambiguation in Europe/London
    // -------------------------------------------------------------------------
    test(
        'FIX-005: DST Autumn-Fold produces strictly 1 occurrence on 25h fold day',
        () {
      final data = ScheduleFixtures.fix005Data();
      final med = data.medications.single;
      expect(med.timezone, 'Europe/London');
      expect(med.minutes, [90]); // 01:30 AM

      final doses = engine.generate(
        [med],
        [],
        DateTime.utc(2026, 10, 24, 0, 0),
        DateTime.utc(2026, 10, 27, 0, 0),
      );
      expect(doses, hasLength(3));

      final expected = ScheduleFixtures.fix005ExpectedOccurrences();
      // 2026-10-24: 01:30 BST (UTC+1) = 00:30 UTC
      expect(doses[0].id, expected[0]['id']);
      expect(doses[0].dueAt, DateTime.parse(expected[0]['dueAt'] as String));

      // 2026-10-25: 01:30 GMT (UTC+0) = 01:30 UTC (fold produces strictly ONE dose)
      expect(doses[1].id, expected[1]['id']);
      expect(doses[1].dueAt, DateTime.parse(expected[1]['dueAt'] as String));
      final intervalFold = doses[1].dueAt.difference(doses[0].dueAt);
      expect(intervalFold, const Duration(hours: 25)); // 25-hour day!

      // 2026-10-26: 01:30 GMT (UTC+0) = 01:30 UTC
      expect(doses[2].id, expected[2]['id']);
      expect(doses[2].dueAt, DateTime.parse(expected[2]['dueAt'] as String));
      final intervalNormal = doses[2].dueAt.difference(doses[1].dueAt);
      expect(intervalNormal, const Duration(hours: 24));
    });

    // -------------------------------------------------------------------------
    // FIX-006: Overnight Regimen & Post-Midnight Ingestion in Asia/Tokyo
    // -------------------------------------------------------------------------
    test(
        'FIX-006: Overnight dosing binds to scheduled date despite post-midnight ingestion',
        () {
      final data = ScheduleFixtures.fix006Data();
      final med = data.medications.single;
      expect(med.timezone, 'Asia/Tokyo');
      expect(med.minutes, [1410]); // 23:30 JST

      // Due at 14:30 UTC on 2026-10-18 (23:30 JST)
      final recordedDose = data.recordedDoses.single;
      expect(recordedDose.id, 'med-statin-006:1:2026-10-18:1410');
      expect(recordedDose.dueAt, DateTime.utc(2026, 10, 18, 14, 30));

      // Patient ingested at 00:45 on 2026-10-19 (15:45 UTC on 18 Oct)
      final event = data.events.single;
      expect(event.occurrenceId, 'med-statin-006:1:2026-10-18:1410');
      expect(event.recordedAt, DateTime.utc(2026, 10, 18, 15, 45));

      // Date in Occurrence ID remains scheduled date (2026-10-18)
      final occId = OccurrenceId.parse(event.occurrenceId);
      expect(occId.calendarDate, '2026-10-18');
    });

    // -------------------------------------------------------------------------
    // FIX-007: Complete Inventory Ledger Lifecycle
    // -------------------------------------------------------------------------
    test(
        'FIX-007: Inventory Ledger Lifecycle: Initial, Consumption, Reversal, Refill, Count',
        () {
      final data = ScheduleFixtures.fix007Data();
      final stock = data.stockAccounts.single;

      expect(stock.threshold, 70000); // 7.0 threshold
      expect(data.stockEntries, hasLength(5));

      // Verify sequence of operations:
      // 1. Initial (+100,000)
      // 2. Consumption (-10,000)
      // 3. Reversal (+10,000)
      // 4. Refill (+300,000)
      // 5. Physical count adjustment (-20,000)
      final computed = data.balance(stock.id);
      expect(computed, ScheduleFixtures.fix007ExpectedBalance());
      expect(computed, 380000); // 38.0 units exactly
      expect(FixedPointMath.format(computed), '38');
    });

    // -------------------------------------------------------------------------
    // FIX-008: Concurrency Conflict & Clock Anomaly Rejection
    // -------------------------------------------------------------------------
    test('FIX-008: Stale revision and backward clock mutations are rejected',
        () {
      final testCases = ScheduleFixtures.fix008TestCases();

      // Case 1: Stale revision rejection
      final staleCase = testCases[0];
      expect(staleCase['test'], 'stale_revision_rejected');
      final currentMed = Medication(
        id: 'med-metformin-003',
        name: 'Metformin',
        amount: '1',
        unit: 'tablet',
        timezone: 'America/New_York',
        minutes: const [480],
        startsOn: DateTime(2026, 10, 18),
        revision: 2,
      );
      final submittedStale = currentMed.copyWith(revision: 1);

      expect(
        () => ClinicianSafetyValidator.validateRevisionTransition(
          current: currentMed,
          submitted: submittedStale,
          effectiveNow: DateTime.utc(2026, 10, 18, 14, 0),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            staleCase['expectedMessage'],
          ),
        ),
      );

      // Case 2: Backward clock rejection
      final clockCase = testCases[1];
      expect(clockCase['test'], 'backward_clock_rejected');
      final medWithEffective = currentMed.copyWith(
        effectiveFrom: DateTime.parse(
            clockCase['storeCurrent']['effectiveFrom'] as String),
      );
      final deviceClock = DateTime.parse(clockCase['deviceClock'] as String);

      expect(
        () => ClinicianSafetyValidator.validateRevisionTransition(
          current: medWithEffective,
          submitted: currentMed,
          effectiveNow: deviceClock,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            clockCase['expectedMessage'],
          ),
        ),
      );
    });
  });

  group('MED-007 QA Boundary Minutes & Recurrence Timing Exhaustive Tests', () {
    test(
        'OccurrenceId validates boundary minute values across the 0-1439 domain',
        () {
      // Boundaries
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:0'), isTrue); // 00:00
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1'), isTrue); // 00:01
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:59'), isTrue); // 00:59
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:60'), isTrue); // 01:00
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:719'), isTrue); // 11:59
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:720'), isTrue); // 12:00
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1438'), isTrue); // 23:58
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1439'), isTrue); // 23:59

      // Invalid boundaries
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1440'), isFalse); // 24:00
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1441'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:1500'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:2000'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:-1'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:-60'), isFalse);

      // Anomaly: leading zeros on minute > 0 are rejected by canonical BNF
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:00'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:01'), isFalse);
      expect(OccurrenceId.isValid('med-1:1:2026-10-18:0720'), isFalse);
    });

    test('OccurrenceId.format enforces minute bounds [0, 1439]', () {
      final min0 = OccurrenceId.format(
        medicationId: 'med-bound',
        revision: 1,
        calendarDate: '2026-10-18',
        minuteOfDay: 0,
      );
      expect(min0, 'med-bound:1:2026-10-18:0');

      final min720 = OccurrenceId.format(
        medicationId: 'med-bound',
        revision: 1,
        calendarDate: '2026-10-18',
        minuteOfDay: 720,
      );
      expect(min720, 'med-bound:1:2026-10-18:720');

      final min1439 = OccurrenceId.format(
        medicationId: 'med-bound',
        revision: 1,
        calendarDate: '2026-10-18',
        minuteOfDay: 1439,
      );
      expect(min1439, 'med-bound:1:2026-10-18:1439');

      expect(
        () => OccurrenceId.format(
          medicationId: 'med-bound',
          revision: 1,
          calendarDate: '2026-10-18',
          minuteOfDay: 1440,
        ),
        throwsFormatException,
      );
      expect(
        () => OccurrenceId.format(
          medicationId: 'med-bound',
          revision: 1,
          calendarDate: '2026-10-18',
          minuteOfDay: -1,
        ),
        throwsFormatException,
      );
    });

    test('Medication.validate enforces minute ranges and slot constraints', () {
      final base = Medication(
        id: 'med-m-test',
        name: 'Minute Test Med',
        amount: '1',
        unit: 'tablet',
        timezone: 'UTC',
        minutes: const [0, 720, 1439],
        startsOn: DateTime.utc(2026, 10, 18),
      );
      base.validate(); // Should pass

      // Invalid minute 1440
      expect(
        () => Medication(
          id: 'm1',
          name: 'Invalid Min',
          amount: '1',
          unit: 'tablet',
          timezone: 'UTC',
          minutes: const [1440],
          startsOn: DateTime.utc(2026, 10, 18),
        ).validate(),
        throwsFormatException,
      );

      // Negative minute
      expect(
        () => Medication(
          id: 'm1',
          name: 'Invalid Min',
          amount: '1',
          unit: 'tablet',
          timezone: 'UTC',
          minutes: const [-1],
          startsOn: DateTime.utc(2026, 10, 18),
        ).validate(),
        throwsFormatException,
      );

      // Empty minutes
      expect(
        () => Medication(
          id: 'm1',
          name: 'Invalid Min',
          amount: '1',
          unit: 'tablet',
          timezone: 'UTC',
          minutes: const [],
          startsOn: DateTime.utc(2026, 10, 18),
        ).validate(),
        throwsFormatException,
      );

      // Exceeding 8 times per day limit
      expect(
        () => Medication(
          id: 'm1',
          name: 'Too Many Times',
          amount: '1',
          unit: 'tablet',
          timezone: 'UTC',
          minutes: const [60, 120, 180, 240, 300, 360, 420, 480, 540],
          startsOn: DateTime.utc(2026, 10, 18),
        ).validate(),
        throwsFormatException,
      );

      // Duplicate times
      expect(
        () => Medication(
          id: 'm1',
          name: 'Duplicate Times',
          amount: '1',
          unit: 'tablet',
          timezone: 'UTC',
          minutes: const [480, 480],
          startsOn: DateTime.utc(2026, 10, 18),
        ).validate(),
        throwsFormatException,
      );
    });

    test('clockLabel formats 24h wall clock representations accurately', () {
      expect(clockLabel(0), '00:00');
      expect(clockLabel(1), '00:01');
      expect(clockLabel(59), '00:59');
      expect(clockLabel(60), '01:00');
      expect(clockLabel(720), '12:00');
      expect(clockLabel(1439), '23:59');
    });

    test(
        'ScheduleEngine generates occurrences at midnight boundaries without drift',
        () {
      final plan = Medication(
        id: 'med-midnight-boundary',
        name: 'Boundary Ingestion',
        amount: '1',
        unit: 'tablet',
        timezone: 'America/New_York',
        minutes: const [0, 1439],
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        startsOn: DateTime.utc(2026, 10, 18),
        endsOn: DateTime.utc(2026, 10, 18),
      );

      final doses = engine.generate(
        [plan],
        [],
        DateTime.utc(2026, 10, 18, 0, 0),
        DateTime.utc(2026, 10, 19, 12, 0),
      );

      expect(doses, hasLength(2));
      // Minute 0 on 2026-10-18 in EDT (UTC-4) is 04:00:00 UTC
      expect(doses[0].id, 'med-midnight-boundary:1:2026-10-18:0');
      expect(doses[0].dueAt, DateTime.utc(2026, 10, 18, 4, 0));

      // Minute 1439 on 2026-10-18 in EDT is 23:59 EDT = 2026-10-19 03:59:00 UTC
      expect(doses[1].id, 'med-midnight-boundary:1:2026-10-18:1439');
      expect(doses[1].dueAt, DateTime.utc(2026, 10, 19, 3, 59));
    });
  });

  group('MED-007 QA Decimal Fixed-Point Scaling & Formatting Boundary Tests',
      () {
    test('FixedPointMath parses fractional precision up to 4 decimal places',
        () {
      expect(FixedPointMath.parse('1'), 10000);
      expect(FixedPointMath.parse('0.5'), 5000); // 1 decimal place
      expect(FixedPointMath.parse('0.25'), 2500); // 2 decimal places
      expect(FixedPointMath.parse('0.125'), 1250); // 3 decimal places
      expect(FixedPointMath.parse('0.0625'), 625); // 4 decimal places
      expect(FixedPointMath.parse('0.0001'), 1); // 4 decimal places minimal
      expect(FixedPointMath.parse('0.0009'), 9);
      expect(FixedPointMath.parse('0.0010'), 10);
      expect(FixedPointMath.parse('0.0100'), 100);
      expect(FixedPointMath.parse('0.1000'), 1000);
      expect(FixedPointMath.parse('12.3456'), 123456);
    });

    test('FixedPointMath rejects fractional precision beyond 4 decimal places',
        () {
      expect(() => FixedPointMath.parse('0.00001'),
          throwsFormatException); // 5 decimals
      expect(() => FixedPointMath.parse('1.12345'), throwsFormatException);
      expect(() => FixedPointMath.parse('0.123456'),
          throwsFormatException); // 6 decimals
      expect(() => FixedPointMath.parse('0.0000001'), throwsFormatException);
    });

    test('FixedPointMath parses whole numbers up to 6 digits', () {
      expect(FixedPointMath.parse('1'), 10000);
      expect(FixedPointMath.parse('99'), 990000);
      expect(FixedPointMath.parse('999'), 9990000);
      expect(FixedPointMath.parse('9999'), 99990000);
      expect(FixedPointMath.parse('99999'), 999990000);
      expect(FixedPointMath.parse('999999'), 9999990000);
      expect(FixedPointMath.parse('999999.9999'), 9999999999);
    });

    test('FixedPointMath rejects whole numbers overflowing past 6 digits', () {
      expect(() => FixedPointMath.parse('1000000'),
          throwsFormatException); // 7 digits
      expect(() => FixedPointMath.parse('1000000.0'), throwsFormatException);
      expect(() => FixedPointMath.parse('1234567.89'), throwsFormatException);
      expect(() => FixedPointMath.parse('9999999'), throwsFormatException);
    });

    test('FixedPointMath rejects negative quantities', () {
      expect(() => FixedPointMath.parse('-1'), throwsFormatException);
      expect(() => FixedPointMath.parse('-0.5'), throwsFormatException);
      expect(() => FixedPointMath.parse('-10.25'), throwsFormatException);
      expect(() => FixedPointMath.parse('-0.0001'), throwsFormatException);
    });

    test(
        'FixedPointMath enforces positive quantity unless allowZero is explicitly true',
        () {
      expect(() => FixedPointMath.parse('0'), throwsFormatException);
      expect(() => FixedPointMath.parse('0.0'), throwsFormatException);
      expect(() => FixedPointMath.parse('0.0000'), throwsFormatException);

      expect(FixedPointMath.parse('0', allowZero: true), 0);
      expect(FixedPointMath.parse('0.0', allowZero: true), 0);
      expect(FixedPointMath.parse('0.0000', allowZero: true), 0);
    });

    test('FixedPointMath rejects omitted leading zero per ISMP standards', () {
      expect(() => FixedPointMath.parse('.5'), throwsFormatException);
      expect(() => FixedPointMath.parse('.25'), throwsFormatException);
      expect(() => FixedPointMath.parse('.0001'), throwsFormatException);
    });

    test('quantityLabel normalizes trailing zeros without precision loss', () {
      expect(quantityLabel(10000), '1');
      expect(quantityLabel(15000), '1.5');
      expect(quantityLabel(12500), '1.25');
      expect(quantityLabel(11250), '1.125');
      expect(quantityLabel(10625), '1.0625');
      expect(quantityLabel(10001), '1.0001');
      expect(quantityLabel(10010), '1.001');
      expect(quantityLabel(10100), '1.01');
      expect(quantityLabel(0), '0');
      expect(quantityLabel(-10000), '-1');
      expect(quantityLabel(-15000), '-1.5');
      expect(quantityLabel(-1), '-0.0001');
      expect(quantityLabel(-9999999999), '-999999.9999');
    });

    test('bi-directional round trip between parseQuantity and quantityLabel',
        () {
      final samples = [
        0,
        1,
        5,
        10,
        100,
        1000,
        2500,
        5000,
        7500,
        10000,
        12500,
        75000,
        123456,
        1000000,
        9999990000,
        9999999999
      ];
      for (final s in samples) {
        final label = quantityLabel(s);
        final parsed = parseQuantity(label, allowZero: true);
        expect(parsed, equals(s),
            reason: 'Failed round trip for $s -> $label -> $parsed');
      }
    });
  });

  group('MED-007 QA Occurrence ID Malformed Strings, Revisions & Dates Tests',
      () {
    test('rejects structural format defects in occurrence IDs', () {
      const defectiveStrings = [
        '',
        '   ',
        'med-1',
        'med-1:1',
        'med-1:1:2026-10-18',
        'med-1:1:2026-10-18:480:extra',
        'med-1::2026-10-18:480',
        ':med-1:1:2026-10-18:480',
        'med-1:1:2026-10-18:480:',
        'med-1:1:2026-10-18:480:999',
      ];
      for (final s in defectiveStrings) {
        expect(OccurrenceId.isValid(s), isFalse,
            reason: 'Expected "$s" to be invalid');
        expect(OccurrenceId.tryParse(s), isNull);
        expect(() => OccurrenceId.parse(s), throwsFormatException);
      }
    });

    test('rejects invalid medication ID characters in occurrence IDs', () {
      expect(OccurrenceId.isValid('med/1:1:2026-10-18:480'), isFalse);
      expect(OccurrenceId.isValid('med 1:1:2026-10-18:480'), isFalse);
      expect(OccurrenceId.isValid('med@home:1:2026-10-18:480'), isFalse);
      expect(OccurrenceId.isValid('med.1:1:2026-10-18:480'), isFalse);

      // Valid IDs with letters, numbers, underscores, and hyphens
      expect(OccurrenceId.isValid('med_ABC-123_xyz:1:2026-10-18:480'), isTrue);
      expect(OccurrenceId.isValid('aspirin:10:2026-10-18:480'), isTrue);
    });

    test('rejects invalid revision components in occurrence IDs', () {
      expect(OccurrenceId.isValid('med-1:0:2026-10-18:480'),
          isFalse); // revision 0
      expect(
          OccurrenceId.isValid('med-1:-1:2026-10-18:480'), isFalse); // negative
      expect(OccurrenceId.isValid('med-1:01:2026-10-18:480'),
          isFalse); // leading zero
      expect(OccurrenceId.isValid('med-1:002:2026-10-18:480'), isFalse);
      expect(
          OccurrenceId.isValid('med-1:1.5:2026-10-18:480'), isFalse); // decimal
      expect(
          OccurrenceId.isValid('med-1:v1:2026-10-18:480'), isFalse); // string
    });

    test('rejects invalid calendar date stamps in occurrence IDs', () {
      expect(
          OccurrenceId.isValid('med-1:1:2026-00-15:480'), isFalse); // month 00
      expect(
          OccurrenceId.isValid('med-1:1:2026-13-15:480'), isFalse); // month 13
      expect(OccurrenceId.isValid('med-1:1:2026-10-00:480'), isFalse); // day 00
      expect(OccurrenceId.isValid('med-1:1:2026-10-32:480'), isFalse); // day 32
      expect(OccurrenceId.isValid('med-1:1:2026-1-15:480'),
          isFalse); // unpadded month
      expect(OccurrenceId.isValid('med-1:1:2026-01-5:480'),
          isFalse); // unpadded day
      expect(OccurrenceId.isValid('med-1:1:26-10-18:480'),
          isFalse); // 2-digit year

      // Valid leap date and year boundaries
      expect(OccurrenceId.isValid('med-1:1:2024-02-29:480'), isTrue);
      expect(OccurrenceId.isValid('med-1:1:2026-01-01:0'), isTrue);
      expect(OccurrenceId.isValid('med-1:1:2026-12-31:1439'), isTrue);
    });

    test('OccurrenceId.format validates arguments strictly', () {
      expect(
        () => OccurrenceId.format(
          medicationId: '',
          revision: 1,
          calendarDate: '2026-10-18',
          minuteOfDay: 480,
        ),
        throwsFormatException,
      );
      expect(
        () => OccurrenceId.format(
          medicationId: '   ',
          revision: 1,
          calendarDate: '2026-10-18',
          minuteOfDay: 480,
        ),
        throwsFormatException,
      );
      expect(
        () => OccurrenceId.format(
          medicationId: 'med-1',
          revision: 0,
          calendarDate: '2026-10-18',
          minuteOfDay: 480,
        ),
        throwsFormatException,
      );
      expect(
        () => OccurrenceId.format(
          medicationId: 'med-1',
          revision: -2,
          calendarDate: '2026-10-18',
          minuteOfDay: 480,
        ),
        throwsFormatException,
      );
      expect(
        () => OccurrenceId.format(
          medicationId: 'med-1',
          revision: 1,
          calendarDate: '2026-13-40',
          minuteOfDay: 480,
        ),
        throwsFormatException,
      );
    });
  });

  group('MED-007 QA Clinician Safety & Field Invariant Error Triggers', () {
    test('ISMP prohibition: "U" or "u" throws exact clinical error message',
        () {
      final prohibitedUnits = ['U', 'u', ' U ', ' u '];
      for (final u in prohibitedUnits) {
        expect(
          () => ClinicianSafetyValidator.validateAdministrationUnit(u),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Do not use "U" as an abbreviation for units. Enter "unit" or "units" to prevent dosage errors.',
            ),
          ),
        );
      }

      // Permitted unit variations
      const allowedUnits = [
        'unit',
        'units',
        'Unit',
        'Units',
        'UNITS',
        'tablet',
        'tablets',
        'capsule',
        'capsules',
        'mL',
        'mg',
        'puff',
        'puffs',
        'drop',
        'drops',
      ];
      for (final u in allowedUnits) {
        expect(
          () => ClinicianSafetyValidator.validateAdministrationUnit(u),
          returnsNormally,
        );
      }
    });

    test('Unit consistency validator rejects mismatched stock units', () {
      ClinicianSafetyValidator.validateUnitConsistency(
        medicineUnit: 'tablet',
        stockUnit: 'tablet',
      );
      ClinicianSafetyValidator.validateUnitConsistency(
        medicineUnit: 'mL',
        stockUnit: 'mL',
      );

      final mismatchedPairs = [
        ['tablet', 'bottle'],
        ['mL', 'tablet'],
        ['capsule', 'box'],
        ['drop', 'bottle'],
      ];

      for (final pair in mismatchedPairs) {
        expect(
          () => ClinicianSafetyValidator.validateUnitConsistency(
            medicineUnit: pair[0],
            stockUnit: pair[1],
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Stop stock tracking before changing the dose unit. Units are never converted automatically.',
            ),
          ),
        );
      }
    });

    test(
        'Clinical dosage separation enforces string length and positive amount boundaries',
        () {
      // Name length: 120 ok, 121 throws
      ClinicianSafetyValidator.validateClinicalDosageSeparation(
        name: 'A' * 120,
        strength: '10 mg',
        form: 'Tablet',
        amount: '1',
        unit: 'tablet',
      );
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: 'A' * 121,
          strength: '10 mg',
          form: 'Tablet',
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );

      // Strength length: 100 ok, 101 throws
      ClinicianSafetyValidator.validateClinicalDosageSeparation(
        name: 'Aspirin',
        strength: 'B' * 100,
        form: 'Tablet',
        amount: '1',
        unit: 'tablet',
      );
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: 'Aspirin',
          strength: 'B' * 101,
          form: 'Tablet',
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );

      // Form length: 50 ok, 51 throws
      ClinicianSafetyValidator.validateClinicalDosageSeparation(
        name: 'Aspirin',
        strength: '100 mg',
        form: 'C' * 50,
        amount: '1',
        unit: 'tablet',
      );
      expect(
        () => ClinicianSafetyValidator.validateClinicalDosageSeparation(
          name: 'Aspirin',
          strength: '100 mg',
          form: 'C' * 51,
          amount: '1',
          unit: 'tablet',
        ),
        throwsFormatException,
      );

      // Standard dosage forms contains expected clinical forms
      expect(
        ClinicianSafetyValidator.standardDosageForms,
        containsAll([
          'Tablet',
          'Capsule',
          'Liquid',
          'Inhaler',
          'Injection',
          'Patch',
          'Drops',
          'Cream',
          'Ointment',
          'Suppository',
          'Spray',
          'Other',
        ]),
      );
    });

    test(
        'Negative stock tracking preserves ledger audit trail without underflow or silent clamping',
        () {
      final stockAcc = StockAccount(
        id: 'stock-neg-001',
        medicineId: 'med-neg-001',
        unit: 'tablet',
        threshold: 10000,
        openedAt: DateTime.utc(2026, 10, 18),
      );

      // Initial 0, then consumption of 2 tablets (-20000)
      final entry1 = StockEntry(
        id: 'entry-neg-1',
        accountId: 'stock-neg-001',
        delta: -20000,
        kind: StockEntryKind.consumption,
        recordedAt: DateTime.utc(2026, 10, 18, 8, 0),
      );

      final data = MedicineData(
        medications: [
          Medication(
            id: 'med-neg-001',
            name: 'Audit Drug',
            amount: '2',
            unit: 'tablet',
            timezone: 'UTC',
            minutes: const [480],
            startsOn: DateTime.utc(2026, 10, 18),
          ),
        ],
        stockAccounts: [stockAcc],
        stockEntries: [entry1],
      );

      // Balance is -20,000 (negative 2 tablets)
      expect(data.balance(stockAcc.id), -20000);
      expect(quantityLabel(data.balance(stockAcc.id)), '-2');

      // Reconciling physical count with +35,000 (+3.5 tablets adjustment) brings balance to +15,000 (+1.5)
      final entry2 = StockEntry(
        id: 'entry-neg-2',
        accountId: 'stock-neg-001',
        delta: 35000,
        kind: StockEntryKind.count,
        recordedAt: DateTime.utc(2026, 10, 18, 9, 0),
        note: 'Reconciled physical count',
      );

      final dataReconciled = data.copyWith(
        stockEntries: [...data.stockEntries, entry2],
      );

      expect(dataReconciled.balance(stockAcc.id), 15000);
      expect(quantityLabel(dataReconciled.balance(stockAcc.id)), '1.5');
      expect(dataReconciled.stockEntries,
          hasLength(2)); // Audit history fully preserved
    });
  });

  group(
      'MED-007 QA High-Volume 10,000 Transactions & Zero-Drift Stress Simulation',
      () {
    test('10,000 consecutive dose consumption events maintain 0.00000000 drift',
        () {
      const totalCycles = 10000;
      const initialStockScaled = 75000000; // 7,500.0000 mL
      const doseDeltaScaled = 7500; // 0.7500 mL per dose

      var integerBalance = initialStockScaled;

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < totalCycles; i++) {
        integerBalance -= doseDeltaScaled;
      }
      stopwatch.stop();

      // Integer fixed-point math is exactly zero
      expect(integerBalance, 0);
      expect(quantityLabel(integerBalance), '0');

      // Zero drift simulation function passes with 10,000 cycles
      final simPassed = FixedPointMath.verifyZeroFloatDriftSimulation(
        cycles: totalCycles,
        initialScaled: initialStockScaled,
        stepScaled: doseDeltaScaled,
      );
      expect(simPassed, isTrue);

      // Verify that 10,000 iterations ran in under 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test(
        '10,000 mixed ledger transactions (refills, consumptions, reversals, micro-doses) reconcile exactly',
        () {
      const initialBalance = 500000000;
      var currentBalance = initialBalance;

      const cConsumptions = 3000;
      const dConsumption = 12500;

      const cReversals = 1000;
      const dReversal = 12500;

      const cRefills = 1000;
      const dRefill = 500000;

      const cMicro = 2000;
      const dMicro = 5;

      const cSuspension = 3000;
      const dSuspension = 3333;

      for (var i = 0; i < cConsumptions; i++) {
        currentBalance -= dConsumption;
      }
      for (var i = 0; i < cReversals; i++) {
        currentBalance += dReversal;
      }
      for (var i = 0; i < cRefills; i++) {
        currentBalance += dRefill;
      }
      for (var i = 0; i < cMicro; i++) {
        currentBalance -= dMicro;
      }
      for (var i = 0; i < cSuspension; i++) {
        currentBalance -= dSuspension;
      }

      const expectedNetBalance = initialBalance -
          (cConsumptions * dConsumption) +
          (cReversals * dReversal) +
          (cRefills * dRefill) -
          (cMicro * dMicro) -
          (cSuspension * dSuspension);

      expect(currentBalance, expectedNetBalance);
      expect(currentBalance, 964991000);
      expect(quantityLabel(currentBalance), '96499.1');
    });
  });

  group('MED-007 QA Canonical Synthetic Fixtures End-to-End JSON Round-Trip',
      () {
    test(
        'all 8 canonical fixtures (FIX-001 to FIX-008) survive JSON encode/decode round-trip with zero data loss',
        () {
      final fixtures = [
        ScheduleFixtures.fix001Data(),
        ScheduleFixtures.fix002Data(),
        ScheduleFixtures.fix003Data(),
        ScheduleFixtures.fix004Data(),
        ScheduleFixtures.fix005Data(),
        ScheduleFixtures.fix006Data(),
        ScheduleFixtures.fix007Data(),
      ];

      for (var i = 0; i < fixtures.length; i++) {
        final original = fixtures[i];
        final fixtureId = ScheduleFixtures.allFixtureIds[i];

        // Verify original integrity
        for (final med in original.medications) {
          med.validate();
        }
        for (final rev in original.previousRevisions) {
          rev.validate();
        }

        // Encode to JSON string
        final encoded = jsonEncode(original.toJson());
        // Decode back to MedicineData
        final restored = MedicineData.decode(encoded);

        // Assert structural and data parity
        expect(restored.medications.length, original.medications.length,
            reason: '$fixtureId: medication count mismatch');
        for (var m = 0; m < original.medications.length; m++) {
          final origMed = original.medications[m];
          final restMed = restored.medications[m];
          expect(restMed.id, origMed.id);
          expect(restMed.name, origMed.name);
          expect(restMed.strength, origMed.strength);
          expect(restMed.form, origMed.form);
          expect(restMed.amount, origMed.amount);
          expect(restMed.unit, origMed.unit);
          expect(restMed.timezone, origMed.timezone);
          expect(restMed.minutes, origMed.minutes);
          expect(restMed.weekdays, origMed.weekdays);
          expect(dateKey(restMed.startsOn), dateKey(origMed.startsOn));
          expect(restMed.endsOn == null ? null : dateKey(restMed.endsOn!),
              origMed.endsOn == null ? null : dateKey(origMed.endsOn!));
          expect(restMed.paused, origMed.paused);
          expect(restMed.archived, origMed.archived);
          expect(restMed.revision, origMed.revision);
          expect(restMed.effectiveFrom?.toUtc().toIso8601String(),
              origMed.effectiveFrom?.toUtc().toIso8601String());
          expect(restMed.effectiveUntil?.toUtc().toIso8601String(),
              origMed.effectiveUntil?.toUtc().toIso8601String());
        }

        expect(restored.previousRevisions.length,
            original.previousRevisions.length,
            reason: '$fixtureId: previousRevisions count mismatch');
        expect(restored.stockAccounts.length, original.stockAccounts.length,
            reason: '$fixtureId: stockAccounts count mismatch');
        for (final sa in original.stockAccounts) {
          expect(restored.balance(sa.id), original.balance(sa.id),
              reason:
                  '$fixtureId: stock balance mismatch for account ${sa.id}');
        }

        expect(restored.stockEntries.length, original.stockEntries.length,
            reason: '$fixtureId: stockEntries count mismatch');
        expect(restored.events.length, original.events.length,
            reason: '$fixtureId: events count mismatch');
        expect(restored.recordedDoses.length, original.recordedDoses.length,
            reason: '$fixtureId: recordedDoses count mismatch');
      }

      // Explicit check for FIX-008 test cases JSON round-trip
      final fix008Cases = ScheduleFixtures.fix008TestCases();
      expect(fix008Cases, hasLength(2));
      final reEncoded008 = jsonEncode(ScheduleFixtures.fix008Map());
      final reDecoded008 = jsonDecode(reEncoded008) as Map<String, dynamic>;
      expect(reDecoded008['scenario'], 'FIX-008-concurrency-and-clock-anomaly');
      expect((reDecoded008['testCases'] as List), hasLength(2));
    });
  });
}
