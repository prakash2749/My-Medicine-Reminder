import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/core/services/medicine_reporting.dart';

import '../support/medicine_fakes.dart';

void main() {
  final from = DateTime.utc(2026, 10, 16),
      until = DateTime.utc(2026, 10, 18),
      now = DateTime.utc(2026, 10, 17, 10);
  late Medication plan;
  List<DoseOccurrence> doses(Medication medication) =>
      const ScheduleEngine().generate([medication], [], from, until);
  DoseEvent event(DoseOccurrence d, DoseAction action, String id) =>
      DoseEvent(id: id, occurrenceId: d.id, action: action, recordedAt: now);
  setUp(() {
    tzdata.initializeTimeZones();
    plan = testMedication(zone: 'UTC')
        .copyWith(recordingStartedAt: DateTime.utc(2026, 10, 1));
  });
  test(
    'denominator contains due occurrences only with honest recording states',
    () {
      final scheduled = doses(plan);
      final data = MedicineData(
        medications: [plan],
        events: [
          event(scheduled[0], DoseAction.taken, 'taken'),
          event(scheduled[1], DoseAction.skipped, 'skipped'),
          event(scheduled[2], DoseAction.taken, 'temporary'),
          event(scheduled[2], DoseAction.undo, 'undo'),
          event(scheduled[3], DoseAction.taken, 'early-future'),
        ],
      );
      final report = MedicineHistory.build(data, from, until, now);
      expect(report.eligible, 3);
      expect(report.taken, 1);
      expect(report.skipped, 1);
      expect(report.unconfirmed, 1);
      expect(report.recordedTakenFraction, closeTo(1 / 3, 0.0001));
    },
  );
  test(
      'new tracking baseline excludes earlier unconfirmed schedules as coverage gaps',
      () {
    final current = plan.copyWith(
      recordingStartedAt: DateTime.utc(2026, 10, 17),
    );
    final report = MedicineHistory.build(
      MedicineData(medications: [current]),
      from,
      until,
      now,
    );
    expect(report.eligible, 1);
    expect(report.coverageGaps, 2);
    expect(report.unconfirmed, 1);
  });
  test(
    'legacy coverage is unknown but explicit historical logs remain reportable',
    () {
      final legacy = testMedication(zone: 'UTC');
      final report = MedicineHistory.build(
        MedicineData(
          medications: [legacy],
          events: [event(doses(legacy).first, DoseAction.taken, 'known')],
        ),
        from,
        until,
        now,
      );
      expect(report.eligible, 1);
      expect(report.taken, 1);
      expect(report.coverageGaps, 2);
    },
  );
  test('pause gap is excluded and resume never adds retrospective doses', () {
    final pausedAt = DateTime.utc(2026, 10, 16, 12),
        resumedAt = DateTime.utc(2026, 10, 17, 12);
    final paused = plan.copyWith(
      paused: true,
      revision: 2,
      effectiveFrom: pausedAt,
      effectiveUntil: resumedAt,
    );
    final resumed = plan.copyWith(revision: 3, effectiveFrom: resumedAt);
    final report = MedicineHistory.build(
      MedicineData(
        medications: [resumed],
        previousRevisions: [
          plan.copyWith(effectiveUntil: pausedAt),
          paused,
        ],
      ),
      from,
      until,
      DateTime.utc(2026, 10, 17, 13),
    );
    expect(report.eligible, 1);
    expect(report.doses.single.dueAt, DateTime.utc(2026, 10, 16, 8));
  });
  test('archive and version changes preserve old names and counts', () {
    final archived = plan.copyWith(
      archived: true,
      revision: 2,
      effectiveFrom: now,
    );
    final report = MedicineHistory.build(
      MedicineData(
        medications: [archived],
        previousRevisions: [plan.copyWith(effectiveUntil: now)],
      ),
      from,
      until,
      now,
    );
    expect(report.eligible, 3);
    expect(report.doses.every((d) => d.medication.name == plan.name), isTrue);
  });
  test(
      'canceled future confirmation is kept after due, but its undone record is excluded',
      () {
    final original = doses(plan)[2];
    final boundary = DateTime.utc(2026, 10, 17, 7);
    final data = MedicineData(
      medications: [
        plan.copyWith(archived: true, revision: 2, effectiveFrom: boundary),
      ],
      previousRevisions: [plan.copyWith(effectiveUntil: boundary)],
      recordedDoses: [original],
      events: [event(original, DoseAction.taken, 'early')],
    );
    expect(MedicineHistory.build(data, from, until, now).taken, 1);
    final undone = data.copyWith(
      events: [...data.events, event(original, DoseAction.undo, 'undo')],
    );
    expect(MedicineHistory.build(undone, from, until, now).eligible, 2);
  });
  test(
      'medicine filtering covers archived identities without merging similar names',
      () {
    final other = testMedication(
      id: 'other',
      zone: 'UTC',
    ).copyWith(recordingStartedAt: from);
    final data = MedicineData(medications: [plan, other]);
    expect(
      MedicineHistory.build(
        data,
        from,
        until,
        now,
        medicineId: 'other',
      ).eligible,
      3,
    );
    expect(
      MedicineHistory.build(
        data,
        from,
        until,
        now,
        medicineId: 'absent',
      ).eligible,
      0,
    );
  });
  test(
    'empty period has no invented percentage and excessive range is rejected',
    () {
      final report = MedicineHistory.build(
        const MedicineData(),
        from,
        until,
        now,
      );
      expect(report.eligible, 0);
      expect(report.recordedTakenFraction, 0);
      expect(
        () => MedicineHistory.build(
          const MedicineData(),
          DateTime.utc(2024),
          until,
          now,
        ),
        throwsFormatException,
      );
    },
  );
}
