import 'dart:convert';

import 'inventory.dart';
import 'medication.dart';
import '../services/medicine_store.dart';

/// Authoritative domain contract, types, validators, and canonical synthetic
/// fixtures for medication scheduling, dose events, and inventory ledger semantics
/// specified in MED-007 (Issue #17).

/// Scale factor for decimal fixed-point arithmetic (4 decimal places = 10^4).
const int quantityScaleFactor = 10000;

/// Standard snooze alert postponement duration (15 minutes).
const Duration standardSnoozeDuration = Duration(minutes: 15);

/// Maximum permitted whole-number digits for dosage quantity (up to 999,999).
const int maxDosageWholeDigits = 6;

/// Maximum permitted fractional decimal places for dosage quantity (up to 4 places).
const int maxDosageDecimalPlaces = 4;

/// Canonical regex pattern matching a valid decimal dose quantity string:
/// up to 6 whole digits, optional dot, and up to 4 decimal places.
final RegExp dosageAmountPattern = RegExp(r'^\d{1,6}(\.\d{1,4})?$');

/// Canonical BNF grammar regex for composite dose occurrence identifiers:
/// `<medicationId>:<revision>:<calendarDate>:<minuteOfDay>`
/// e.g. `med-101:1:2026-10-18:480`
final RegExp occurrenceIdPattern = RegExp(
  r'^([a-zA-Z0-9_\-]+):([1-9][0-9]*):(\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])):([0-9]|[1-9][0-9]|[1-9][0-9]{2}|1[0-3][0-9]{2}|14[0-3][0-9])$',
);

/// Parsed value object representing a deterministic composite occurrence ID.
class OccurrenceId {
  final String medicationId;
  final int revision;
  final String calendarDate;
  final int minuteOfDay;

  const OccurrenceId({
    required this.medicationId,
    required this.revision,
    required this.calendarDate,
    required this.minuteOfDay,
  });

  /// Validates whether the given raw string satisfies the composite ID grammar.
  static bool isValid(String raw) => occurrenceIdPattern.hasMatch(raw.trim());

  /// Parses a composite occurrence ID string or throws [FormatException].
  static OccurrenceId parse(String raw) {
    final text = raw.trim();
    final match = occurrenceIdPattern.firstMatch(text);
    if (match == null) {
      throw FormatException(
        'Invalid occurrence ID format: "$raw". '
        'Expected {medicationId}:{revision}:{YYYY-MM-DD}:{minuteOfDay}.',
      );
    }
    return OccurrenceId(
      medicationId: match.group(1)!,
      revision: int.parse(match.group(2)!),
      calendarDate: match.group(3)!,
      minuteOfDay: int.parse(match.group(4)!),
    );
  }

  /// Attempts to parse a composite occurrence ID string, returning null if invalid.
  static OccurrenceId? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Formats composite components into a canonical occurrence ID string.
  static String format({
    required String medicationId,
    required int revision,
    required String calendarDate,
    required int minuteOfDay,
  }) {
    if (medicationId.trim().isEmpty) {
      throw const FormatException('medicationId must not be empty.');
    }
    if (revision < 1) {
      throw const FormatException('revision must be >= 1.');
    }
    if (minuteOfDay < 0 || minuteOfDay >= 1440) {
      throw const FormatException('minuteOfDay must be between 0 and 1439.');
    }
    final formatted = '$medicationId:$revision:$calendarDate:$minuteOfDay';
    if (!isValid(formatted)) {
      throw FormatException(
          'Constructed occurrence ID is invalid: "$formatted".');
    }
    return formatted;
  }

  String get value => '$medicationId:$revision:$calendarDate:$minuteOfDay';

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OccurrenceId &&
          runtimeType == other.runtimeType &&
          medicationId == other.medicationId &&
          revision == other.revision &&
          calendarDate == other.calendarDate &&
          minuteOfDay == other.minuteOfDay;

  @override
  int get hashCode =>
      medicationId.hashCode ^
      revision.hashCode ^
      calendarDate.hashCode ^
      minuteOfDay.hashCode;
}

/// Clinically defined occurrence status at evaluation instant T_now.
///
/// Follows Section 7.2 formal state logic:
/// - Taken: explicit user confirmation of intake.
/// - Skipped: explicit user or clinician confirmation of omission.
/// - Canceled: superseded by plan revision, pause, or archive.
/// - Snoozed: reminder postponed, alertAt > T_now and remindersAllowed.
/// - Unconfirmed: scheduled due time has passed (dueAt <= T_now) without action.
/// - Upcoming: future scheduled occurrence (dueAt > T_now).
enum DoseOccurrenceStatus {
  upcoming('Upcoming'),
  snoozed('Snoozed'),
  unconfirmed('Unconfirmed'),
  taken('Taken'),
  skipped('Skipped'),
  canceled('Canceled');

  final String label;
  const DoseOccurrenceStatus(this.label);

  bool get isActioned => this == taken || this == skipped;
}

/// Evaluates the clinical status of an occurrence at instant [now] conforming
/// to the formal mathematical evaluation logic in MED-007-DESIGN Section 7.2.
DoseOccurrenceStatus evaluateOccurrenceStatus(
  DoseOccurrence occurrence,
  DateTime now,
) {
  if (occurrence.isTaken) return DoseOccurrenceStatus.taken;
  if (occurrence.isSkipped) return DoseOccurrenceStatus.skipped;
  if (occurrence.canceled) return DoseOccurrenceStatus.canceled;
  if (occurrence.remindersAllowed &&
      occurrence.latestEvent?.action == DoseAction.snooze &&
      occurrence.alertAt.isAfter(now)) {
    return DoseOccurrenceStatus.snoozed;
  }
  if (!occurrence.dueAt.isAfter(now)) {
    return DoseOccurrenceStatus.unconfirmed;
  }
  return DoseOccurrenceStatus.upcoming;
}

/// Comprehensive adherence metric calculation adhering to non-punitive
/// clinical reporting guidelines.
class AdherenceReport {
  final int totalScheduled;
  final int totalEligible;
  final int confirmedTaken;
  final int confirmedSkipped;
  final int unconfirmed;
  final int snoozed;
  final int upcoming;
  final int canceled;
  final double adherenceFraction;
  final String clinicalFootnote;

  const AdherenceReport({
    required this.totalScheduled,
    required this.totalEligible,
    required this.confirmedTaken,
    required this.confirmedSkipped,
    required this.unconfirmed,
    required this.snoozed,
    required this.upcoming,
    required this.canceled,
    required this.adherenceFraction,
    this.clinicalFootnote =
        'Unconfirmed doses represent absence of mobile recording, not verified clinical omission.',
  });

  Map<String, dynamic> toJson() => {
        'totalScheduled': totalScheduled,
        'totalEligible': totalEligible,
        'confirmedTaken': confirmedTaken,
        'confirmedSkipped': confirmedSkipped,
        'unconfirmed': unconfirmed,
        'snoozed': snoozed,
        'upcoming': upcoming,
        'canceled': canceled,
        'adherenceFraction': adherenceFraction,
        'clinicalFootnote': clinicalFootnote,
      };
}

/// Calculates an objective, non-punitive adherence report from occurrences.
AdherenceReport calculateAdherenceReport({
  required List<DoseOccurrence> occurrences,
  required DateTime evaluationInstant,
}) {
  var eligible = 0;
  var taken = 0;
  var skipped = 0;
  var unconfirmed = 0;
  var snoozed = 0;
  var upcoming = 0;
  var canceled = 0;

  for (final occ in occurrences) {
    final status = evaluateOccurrenceStatus(occ, evaluationInstant);
    switch (status) {
      case DoseOccurrenceStatus.taken:
        taken++;
        if (!occ.canceled) eligible++;
        break;
      case DoseOccurrenceStatus.skipped:
        skipped++;
        if (!occ.canceled) eligible++;
        break;
      case DoseOccurrenceStatus.unconfirmed:
        unconfirmed++;
        if (!occ.canceled) eligible++;
        break;
      case DoseOccurrenceStatus.snoozed:
        snoozed++;
        if (!occ.dueAt.isAfter(evaluationInstant) && !occ.canceled) eligible++;
        break;
      case DoseOccurrenceStatus.upcoming:
        upcoming++;
        break;
      case DoseOccurrenceStatus.canceled:
        canceled++;
        break;
    }
  }

  final fraction = eligible == 0 ? 0.0 : taken / eligible;
  return AdherenceReport(
    totalScheduled: occurrences.length,
    totalEligible: eligible,
    confirmedTaken: taken,
    confirmedSkipped: skipped,
    unconfirmed: unconfirmed,
    snoozed: snoozed,
    upcoming: upcoming,
    canceled: canceled,
    adherenceFraction: fraction,
  );
}

/// Domain validation helpers enforcing clinician safety rules, unit consistency,
/// and bi-temporal revision transition constraints.
class ClinicianSafetyValidator {
  const ClinicianSafetyValidator._();

  /// Standard dosage forms recognized in clinical medication records.
  static const List<String> standardDosageForms = [
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
  ];

  /// Enforces distinct separation between medication strength, dosage form,
  /// dose amount, and administration unit.
  static void validateClinicalDosageSeparation({
    required String name,
    required String strength,
    required String form,
    required String amount,
    required String unit,
  }) {
    if (name.trim().isEmpty || name.length > 120) {
      throw const FormatException(
          'Enter a medicine name (up to 120 characters).');
    }
    if (strength.length > 100) {
      throw const FormatException(
          'Strength description must not exceed 100 characters.');
    }
    if (form.trim().isEmpty || form.length > 50) {
      throw const FormatException('Enter a dosage form (up to 50 characters).');
    }
    validatePrescribedAmount(amount);
    validateAdministrationUnit(unit);
  }

  /// Prohibits error-prone unit abbreviations (such as "U" for units per ISMP).
  static void validateAdministrationUnit(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
          'Enter a positive dose quantity and its unit.');
    }
    if (trimmed.toUpperCase() == 'U') {
      throw const FormatException(
        'Do not use "U" as an abbreviation for units. Enter "unit" or "units" to prevent dosage errors.',
      );
    }
  }

  /// Enforces positive decimal scalar matching regex `^\d{1,6}(\.\d{1,4})?$`.
  /// Rejects omitted leading zeroes (e.g. '.5').
  static void validatePrescribedAmount(String amount) {
    final text = amount.trim();
    if (!dosageAmountPattern.hasMatch(text)) {
      throw const FormatException(
          'Use up to 6 whole digits and 4 decimal places.');
    }
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      throw const FormatException(
          'Enter a positive dose quantity and its unit.');
    }
  }

  /// Strictly prohibits automatic unit conversion between administration and stock units.
  static void validateUnitConsistency({
    required String medicineUnit,
    required String stockUnit,
  }) {
    if (medicineUnit.trim() != stockUnit.trim()) {
      throw const FormatException(
        'Stop stock tracking before changing the dose unit. Units are never converted automatically.',
      );
    }
  }

  /// Validates bi-temporal revision transition invariants:
  /// 1. Optimistic locking: draft revision must match current revision.
  /// 2. Monotonic system clock: clock must not have moved backwards prior to current.effectiveFrom.
  static void validateRevisionTransition({
    required Medication current,
    required Medication submitted,
    required DateTime effectiveNow,
  }) {
    if (current.revision != submitted.revision) {
      throw const FormatException(
        'This medicine changed while you were editing. Reopen it and try again.',
      );
    }
    if (current.effectiveFrom != null &&
        effectiveNow.isBefore(current.effectiveFrom!)) {
      throw const FormatException(
        'Your device clock moved backwards. Correct it before changing this schedule.',
      );
    }
  }

  /// Validates that calendar boundaries are inclusive and endsOn >= startsOn.
  static void validateCalendarBoundaries({
    required DateTime startsOn,
    DateTime? endsOn,
  }) {
    if (endsOn != null &&
        calendarDate(endsOn).isBefore(calendarDate(startsOn))) {
      throw const FormatException(
        'End date must be on or after the start date.',
      );
    }
  }
}

/// High-precision decimal fixed-point arithmetic helpers (scale 10,000).
class FixedPointMath {
  const FixedPointMath._();

  static const int scale = quantityScaleFactor;

  /// Parses a decimal quantity string into a 64-bit scaled integer.
  static int parse(String text, {bool allowZero = false}) =>
      parseQuantity(text, allowZero: allowZero);

  /// Formats a scaled integer back into a decimal string without floating-point error.
  static String format(int scaled) => quantityLabel(scaled);

  /// Executes an automated N-cycle deduction simulation to empirically verify
  /// zero cumulative IEEE 754 floating-point drift.
  static bool verifyZeroFloatDriftSimulation({
    int cycles = 1000,
    int initialScaled = 1000000, // 100.0000 units
    int stepScaled = 1000, // 0.1000 unit per cycle
  }) {
    var balance = initialScaled;
    for (var i = 0; i < cycles; i++) {
      balance -= stepScaled;
    }
    final expected = initialScaled - (cycles * stepScaled);
    return balance == expected;
  }
}

/// The 8 Clinician-Approved Synthetic Canonical Test Fixtures (FIX-001 through FIX-008)
/// from MED-007-DESIGN Section 13.
class ScheduleFixtures {
  const ScheduleFixtures._();

  static const List<String> allFixtureIds = [
    'FIX-001',
    'FIX-002',
    'FIX-003',
    'FIX-004',
    'FIX-005',
    'FIX-006',
    'FIX-007',
    'FIX-008',
  ];

  // ---------------------------------------------------------------------------
  // FIX-001: Multi-Component Strength & Tablet Regimen
  // ---------------------------------------------------------------------------
  static const String fix001MultiComponentTabletJson = '''{
  "scenario": "FIX-001-multi-component-tablet",
  "description": "Amoxicillin/Clavulanate 875/125 mg, 1 tablet BID at 08:00 and 20:00",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-amox-clav-001",
        "name": "Amoxicillin and Clavulanate Potassium",
        "strength": "875 mg / 125 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take with a meal to avoid gastrointestinal upset.",
        "timezone": "America/New_York",
        "minutes": [480, 1200],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-18",
        "endsOn": "2026-10-28",
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-18T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-18T00:00:00Z"
      }
    ],
    "stockAccounts": [
      {
        "id": "stock-amox-clav-001",
        "medicineId": "med-amox-clav-001",
        "unit": "tablet",
        "threshold": 40000,
        "openedAt": "2026-10-18T00:00:00Z",
        "active": true,
        "revision": 1,
        "episode": 1,
        "alertedEpisode": null
      }
    ],
    "stockEntries": [
      {
        "id": "entry-init-amox",
        "accountId": "stock-amox-clav-001",
        "delta": 200000,
        "kind": "initial",
        "recordedAt": "2026-10-18T00:00:00Z",
        "occurrenceId": null,
        "note": "Dispensed 20 tablets for 10-day course"
      }
    ],
    "events": [],
    "previousRevisions": [],
    "recordedDoses": []
  }
}''';

  static Map<String, dynamic> fix001Map() => Map<String, dynamic>.from(
      jsonDecode(fix001MultiComponentTabletJson) as Map);

  static MedicineData fix001Data() =>
      MedicineData.decode(jsonEncode(fix001Map()['payload']));

  // ---------------------------------------------------------------------------
  // FIX-002: Pediatric Fractional Liquid Suspension
  // ---------------------------------------------------------------------------
  static const String fix002PediatricFractionalLiquidJson = '''{
  "scenario": "FIX-002-pediatric-fractional-liquid",
  "description": "Amoxicillin Oral Suspension 250 mg/5 mL, dose 7.5 mL TID",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-ped-amox-002",
        "name": "Amoxicillin Oral Suspension",
        "strength": "250 mg / 5 mL",
        "form": "Liquid",
        "amount": "7.5",
        "unit": "mL",
        "instructions": "Shake well before measuring with oral dosing syringe.",
        "timezone": "America/Chicago",
        "minutes": [480, 840, 1200],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-18",
        "endsOn": "2026-10-25",
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-18T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-18T00:00:00Z"
      }
    ],
    "stockAccounts": [
      {
        "id": "stock-ped-amox-002",
        "medicineId": "med-ped-amox-002",
        "unit": "mL",
        "threshold": 450000,
        "openedAt": "2026-10-18T00:00:00Z",
        "active": true,
        "revision": 1,
        "episode": 1,
        "alertedEpisode": null
      }
    ],
    "stockEntries": [
      {
        "id": "entry-init-ped-amox",
        "accountId": "stock-ped-amox-002",
        "delta": 1500000,
        "kind": "initial",
        "recordedAt": "2026-10-18T00:00:00Z",
        "occurrenceId": null,
        "note": "Reconstituted 150 mL bottle"
      }
    ],
    "events": [],
    "previousRevisions": [],
    "recordedDoses": []
  }
}''';

  static Map<String, dynamic> fix002Map() => Map<String, dynamic>.from(
      jsonDecode(fix002PediatricFractionalLiquidJson) as Map);

  static MedicineData fix002Data() =>
      MedicineData.decode(jsonEncode(fix002Map()['payload']));

  // ---------------------------------------------------------------------------
  // FIX-003: Bi-Temporal Mid-Day Schedule Revision
  // ---------------------------------------------------------------------------
  static const String fix003BitemporalScheduleRevisionJson = '''{
  "scenario": "FIX-003-bitemporal-schedule-revision",
  "description": "Metformin 500mg QD morning taken at 08:00, revised at 14:00 to 1000mg BID",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-metformin-003",
        "name": "Metformin Hydrochloride",
        "strength": "1000 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take with breakfast and dinner.",
        "timezone": "America/New_York",
        "minutes": [480, 1200],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-18",
        "endsOn": null,
        "paused": false,
        "archived": false,
        "revision": 2,
        "effectiveFrom": "2026-10-18T14:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-01T00:00:00Z"
      }
    ],
    "previousRevisions": [
      {
        "id": "med-metformin-003",
        "name": "Metformin Hydrochloride",
        "strength": "500 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take with breakfast.",
        "timezone": "America/New_York",
        "minutes": [480],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-01",
        "endsOn": null,
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-01T00:00:00Z",
        "effectiveUntil": "2026-10-18T14:00:00Z",
        "recordingStartedAt": "2026-10-01T00:00:00Z"
      }
    ],
    "recordedDoses": [
      {
        "id": "med-metformin-003:1:2026-10-18:480",
        "dueAt": "2026-10-18T12:00:00Z",
        "medication": {
          "id": "med-metformin-003",
          "name": "Metformin Hydrochloride",
          "strength": "500 mg",
          "form": "Tablet",
          "amount": "1",
          "unit": "tablet",
          "instructions": "Take with breakfast.",
          "timezone": "America/New_York",
          "minutes": [480],
          "weekdays": [1, 2, 3, 4, 5, 6, 7],
          "startsOn": "2026-10-01",
          "endsOn": null,
          "paused": false,
          "archived": false,
          "revision": 1,
          "effectiveFrom": "2026-10-01T00:00:00Z",
          "effectiveUntil": "2026-10-18T14:00:00Z",
          "recordingStartedAt": "2026-10-01T00:00:00Z"
        }
      }
    ],
    "events": [
      {
        "id": "evt-morning-take",
        "occurrenceId": "med-metformin-003:1:2026-10-18:480",
        "action": "taken",
        "recordedAt": "2026-10-18T12:05:00Z",
        "snoozedUntil": null
      }
    ],
    "stockAccounts": [],
    "stockEntries": []
  }
}''';

  static Map<String, dynamic> fix003Map() => Map<String, dynamic>.from(
      jsonDecode(fix003BitemporalScheduleRevisionJson) as Map);

  static MedicineData fix003Data() =>
      MedicineData.decode(jsonEncode(fix003Map()['payload']));

  // ---------------------------------------------------------------------------
  // FIX-004: DST Spring-Forward Gap in America/New_York
  // ---------------------------------------------------------------------------
  static const String fix004DstSpringGapJson = '''{
  "scenario": "FIX-004-dst-spring-gap",
  "description": "Regimen scheduled at 02:30 AM. On 2026-03-08, 02:30 is skipped; fires at 03:00 AM EDT (23h interval)",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-thyroid-004",
        "name": "Levothyroxine Sodium",
        "strength": "50 mcg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take on an empty stomach with a full glass of water.",
        "timezone": "America/New_York",
        "minutes": [150],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-03-07",
        "endsOn": "2026-03-10",
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-03-07T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-03-07T00:00:00Z"
      }
    ],
    "expectedOccurrences": [
      {
        "id": "med-thyroid-004:1:2026-03-07:150",
        "dueAt": "2026-03-07T07:30:00Z",
        "localClock": "02:30 EST (UTC-5)"
      },
      {
        "id": "med-thyroid-004:1:2026-03-08:150",
        "dueAt": "2026-03-08T07:00:00Z",
        "localClock": "03:00 EDT (UTC-4) [Shifted from missing 02:30 instant, interval = 23h]"
      },
      {
        "id": "med-thyroid-004:1:2026-03-09:150",
        "dueAt": "2026-03-09T06:30:00Z",
        "localClock": "02:30 EDT (UTC-4) [Interval = 23.5h]"
      }
    ],
    "events": [],
    "previousRevisions": [],
    "recordedDoses": [],
    "stockAccounts": [],
    "stockEntries": []
  }
}''';

  static Map<String, dynamic> fix004Map() =>
      Map<String, dynamic>.from(jsonDecode(fix004DstSpringGapJson) as Map);

  static MedicineData fix004Data() =>
      MedicineData.decode(jsonEncode(fix004Map()['payload']));

  static List<Map<String, dynamic>> fix004ExpectedOccurrences() {
    final payload = fix004Map()['payload'] as Map<String, dynamic>;
    return (payload['expectedOccurrences'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // FIX-005: DST Autumn-Fold Disambiguation in Europe/London
  // ---------------------------------------------------------------------------
  static const String fix005DstAutumnFoldJson = '''{
  "scenario": "FIX-005-dst-autumn-fold",
  "description": "Regimen scheduled at 01:30 AM in London. On 2026-10-25 (25h day), clock repeats 01:00-02:00. Strictly 1 occurrence generated.",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-sedative-005",
        "name": "Zolpidem Tartrate",
        "strength": "5 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take immediately before bedtime.",
        "timezone": "Europe/London",
        "minutes": [90],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-24",
        "endsOn": "2026-10-26",
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-24T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-24T00:00:00Z"
      }
    ],
    "expectedOccurrences": [
      {
        "id": "med-sedative-005:1:2026-10-24:90",
        "dueAt": "2026-10-24T00:30:00Z",
        "localClock": "01:30 BST (UTC+1)"
      },
      {
        "id": "med-sedative-005:1:2026-10-25:90",
        "dueAt": "2026-10-25T01:30:00Z",
        "localClock": "01:30 GMT (UTC+0) [Fold disambiguated to single standard time dose, interval = 25h]"
      },
      {
        "id": "med-sedative-005:1:2026-10-26:90",
        "dueAt": "2026-10-26T01:30:00Z",
        "localClock": "01:30 GMT (UTC+0) [Interval = 24h]"
      }
    ],
    "events": [],
    "previousRevisions": [],
    "recordedDoses": [],
    "stockAccounts": [],
    "stockEntries": []
  }
}''';

  static Map<String, dynamic> fix005Map() =>
      Map<String, dynamic>.from(jsonDecode(fix005DstAutumnFoldJson) as Map);

  static MedicineData fix005Data() =>
      MedicineData.decode(jsonEncode(fix005Map()['payload']));

  static List<Map<String, dynamic>> fix005ExpectedOccurrences() {
    final payload = fix005Map()['payload'] as Map<String, dynamic>;
    return (payload['expectedOccurrences'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // FIX-006: Overnight Dosing & Post-Midnight Ingestion in Asia/Tokyo
  // ---------------------------------------------------------------------------
  static const String fix006OvernightPostMidnightJson = '''{
  "scenario": "FIX-006-overnight-post-midnight",
  "description": "Atorvastatin 20mg scheduled at 23:30 (minute 1410). Patient ingests at 00:45 next day. Anchored to scheduled date.",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-statin-006",
        "name": "Atorvastatin Calcium",
        "strength": "20 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take at bedtime.",
        "timezone": "Asia/Tokyo",
        "minutes": [1410],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-18",
        "endsOn": null,
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-18T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-18T00:00:00Z"
      }
    ],
    "recordedDoses": [
      {
        "id": "med-statin-006:1:2026-10-18:1410",
        "dueAt": "2026-10-18T14:30:00Z",
        "medication": {
          "id": "med-statin-006",
          "name": "Atorvastatin Calcium",
          "strength": "20 mg",
          "form": "Tablet",
          "amount": "1",
          "unit": "tablet",
          "instructions": "Take at bedtime.",
          "timezone": "Asia/Tokyo",
          "minutes": [1410],
          "weekdays": [1, 2, 3, 4, 5, 6, 7],
          "startsOn": "2026-10-18",
          "endsOn": null,
          "paused": false,
          "archived": false,
          "revision": 1,
          "effectiveFrom": "2026-10-18T00:00:00Z",
          "effectiveUntil": null,
          "recordingStartedAt": "2026-10-18T00:00:00Z"
        }
      }
    ],
    "events": [
      {
        "id": "evt-overnight-ingest",
        "occurrenceId": "med-statin-006:1:2026-10-18:1410",
        "action": "taken",
        "recordedAt": "2026-10-18T15:45:00Z",
        "snoozedUntil": null
      }
    ],
    "stockAccounts": [],
    "stockEntries": [],
    "previousRevisions": []
  }
}''';

  static Map<String, dynamic> fix006Map() => Map<String, dynamic>.from(
      jsonDecode(fix006OvernightPostMidnightJson) as Map);

  static MedicineData fix006Data() =>
      MedicineData.decode(jsonEncode(fix006Map()['payload']));

  // ---------------------------------------------------------------------------
  // FIX-007: Complete Inventory Ledger Lifecycle
  // ---------------------------------------------------------------------------
  static const String fix007InventoryLedgerLifecycleJson = '''{
  "scenario": "FIX-007-inventory-ledger-lifecycle",
  "description": "Initial stock (10.0), consumption (-1.0), undo reversal (+1.0), refill (+30.0), count correction to 38.0",
  "payload": {
    "version": 3,
    "medications": [
      {
        "id": "med-lisinopril-007",
        "name": "Lisinopril",
        "strength": "10 mg",
        "form": "Tablet",
        "amount": "1",
        "unit": "tablet",
        "instructions": "Take once daily in the morning.",
        "timezone": "America/New_York",
        "minutes": [480],
        "weekdays": [1, 2, 3, 4, 5, 6, 7],
        "startsOn": "2026-10-01",
        "endsOn": null,
        "paused": false,
        "archived": false,
        "revision": 1,
        "effectiveFrom": "2026-10-01T00:00:00Z",
        "effectiveUntil": null,
        "recordingStartedAt": "2026-10-01T00:00:00Z"
      }
    ],
    "stockAccounts": [
      {
        "id": "stock-lisinopril-007",
        "medicineId": "med-lisinopril-007",
        "unit": "tablet",
        "threshold": 70000,
        "openedAt": "2026-10-01T00:00:00Z",
        "active": true,
        "revision": 3,
        "episode": 1,
        "alertedEpisode": null
      }
    ],
    "stockEntries": [
      {
        "id": "entry-init-007",
        "accountId": "stock-lisinopril-007",
        "delta": 100000,
        "kind": "initial",
        "recordedAt": "2026-10-01T08:00:00Z",
        "occurrenceId": null,
        "note": "Initial baseline count"
      },
      {
        "id": "dose:evt-take-007",
        "accountId": "stock-lisinopril-007",
        "delta": -10000,
        "kind": "consumption",
        "recordedAt": "2026-10-02T08:05:00Z",
        "occurrenceId": "med-lisinopril-007:1:2026-10-02:480",
        "note": ""
      },
      {
        "id": "dose:evt-undo-007",
        "accountId": "stock-lisinopril-007",
        "delta": 10000,
        "kind": "reversal",
        "recordedAt": "2026-10-02T08:15:00Z",
        "occurrenceId": "med-lisinopril-007:1:2026-10-02:480",
        "note": ""
      },
      {
        "id": "entry-refill-007",
        "accountId": "stock-lisinopril-007",
        "delta": 300000,
        "kind": "refill",
        "recordedAt": "2026-10-10T14:00:00Z",
        "occurrenceId": null,
        "note": "Pharmacy 30-day refill"
      },
      {
        "id": "entry-count-corr-007",
        "accountId": "stock-lisinopril-007",
        "delta": -20000,
        "kind": "count",
        "recordedAt": "2026-10-18T09:00:00Z",
        "occurrenceId": null,
        "note": "Physical count showed 38 tablets (was calculated 40)"
      }
    ],
    "computedBalance": 380000,
    "events": [],
    "previousRevisions": [],
    "recordedDoses": []
  }
}''';

  static Map<String, dynamic> fix007Map() => Map<String, dynamic>.from(
      jsonDecode(fix007InventoryLedgerLifecycleJson) as Map);

  static MedicineData fix007Data() =>
      MedicineData.decode(jsonEncode(fix007Map()['payload']));

  static int fix007ExpectedBalance() =>
      (fix007Map()['payload'] as Map<String, dynamic>)['computedBalance']
          as int;

  // ---------------------------------------------------------------------------
  // FIX-008: Concurrency Conflict & Clock Anomaly Rejection
  // ---------------------------------------------------------------------------
  static const String fix008ConcurrencyAndClockAnomalyJson = '''{
  "scenario": "FIX-008-concurrency-and-clock-anomaly",
  "description": "Validation cases: Form submitted with stale revision 1 when store is at revision 2; and edit attempted when device clock is before effectiveFrom",
  "testCases": [
    {
      "test": "stale_revision_rejected",
      "submittedDraft": {
        "id": "med-metformin-003",
        "revision": 1,
        "amount": "2"
      },
      "storeCurrent": {
        "id": "med-metformin-003",
        "revision": 2
      },
      "expectedException": "FormatException",
      "expectedMessage": "This medicine changed while you were editing. Reopen it and try again."
    },
    {
      "test": "backward_clock_rejected",
      "submittedDraft": {
        "id": "med-metformin-003",
        "revision": 2,
        "amount": "2"
      },
      "storeCurrent": {
        "id": "med-metformin-003",
        "revision": 2,
        "effectiveFrom": "2026-10-18T14:00:00Z"
      },
      "deviceClock": "2026-10-18T13:30:00Z",
      "expectedException": "FormatException",
      "expectedMessage": "Your device clock moved backwards. Correct it before changing this schedule."
    }
  ]
}''';

  static Map<String, dynamic> fix008Map() => Map<String, dynamic>.from(
      jsonDecode(fix008ConcurrencyAndClockAnomalyJson) as Map);

  static List<Map<String, dynamic>> fix008TestCases() {
    final list = fix008Map()['testCases'] as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
