import 'package:timezone/timezone.dart' as tz;

DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String clockLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

/// A plan is distinct from each dated dose and its action history.
class Medication {
  final String id, name, strength, form, amount, unit, instructions, timezone;
  final List<int> minutes, weekdays;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool paused, archived;
  final int revision;
  final DateTime? effectiveFrom, effectiveUntil;
  final DateTime? recordingStartedAt;

  const Medication({
    required this.id,
    required this.name,
    this.strength = '',
    this.form = 'Tablet',
    required this.amount,
    required this.unit,
    this.instructions = '',
    required this.timezone,
    required this.minutes,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    required this.startsOn,
    this.endsOn,
    this.paused = false,
    this.archived = false,
    this.revision = 1,
    this.effectiveFrom,
    this.effectiveUntil,
    this.recordingStartedAt,
  });

  void validate() {
    if (id.isEmpty ||
        name.trim().isEmpty ||
        name.length > 120 ||
        strength.length > 100 ||
        instructions.length > 1000) {
      throw const FormatException(
        'Enter a medicine name (up to 120 characters).',
      );
    }
    final quantity = double.tryParse(amount);
    if (!RegExp(r'^\d{1,6}(\.\d{1,4})?$').hasMatch(amount) ||
        quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        unit.trim().isEmpty) {
      throw const FormatException(
        'Enter a positive dose quantity and its unit.',
      );
    }
    if (minutes.isEmpty ||
        minutes.length > 8 ||
        minutes.toSet().length != minutes.length ||
        minutes.any((m) => m < 0 || m >= 1440)) {
      throw const FormatException('Choose 1–8 different reminder times.');
    }
    if (weekdays.isEmpty ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((d) => d < 1 || d > 7)) {
      throw const FormatException('Choose at least one weekday.');
    }
    if (endsOn != null &&
        calendarDate(endsOn!).isBefore(calendarDate(startsOn))) {
      throw const FormatException(
        'End date must be on or after the start date.',
      );
    }
    tz.getLocation(
      timezone,
    ); // Never silently substitute UTC for an invalid zone.
  }

  Medication copyWith({
    bool? paused,
    bool? archived,
    int? revision,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
    DateTime? recordingStartedAt,
  }) =>
      Medication(
        id: id,
        name: name,
        strength: strength,
        form: form,
        amount: amount,
        unit: unit,
        instructions: instructions,
        timezone: timezone,
        minutes: minutes,
        weekdays: weekdays,
        startsOn: startsOn,
        endsOn: endsOn,
        paused: paused ?? this.paused,
        archived: archived ?? this.archived,
        revision: revision ?? this.revision,
        effectiveFrom: effectiveFrom ?? this.effectiveFrom,
        effectiveUntil: effectiveUntil ?? this.effectiveUntil,
        recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'strength': strength,
        'form': form,
        'amount': amount,
        'unit': unit,
        'instructions': instructions,
        'timezone': timezone,
        'minutes': minutes,
        'weekdays': weekdays,
        'startsOn': dateKey(startsOn),
        'endsOn': endsOn == null ? null : dateKey(endsOn!),
        'paused': paused,
        'archived': archived,
        'revision': revision,
        'effectiveFrom': effectiveFrom?.toUtc().toIso8601String(),
        'effectiveUntil': effectiveUntil?.toUtc().toIso8601String(),
        'recordingStartedAt': recordingStartedAt?.toUtc().toIso8601String(),
      };

  factory Medication.fromJson(Map<String, dynamic> j) {
    List<int> parseMinutes() {
      if (j['minutes'] != null) {
        return List<int>.from(j['minutes'] as List);
      }
      if (j['times'] != null) {
        return (j['times'] as List).map((t) {
          final parts = (t as String).split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }).toList();
      }
      return const [540];
    }

    return Medication(
      id: j['id'] as String,
      name: j['name'] as String,
      strength: (j['strength'] ?? '') as String,
      form: (j['form'] ?? 'Tablet') as String,
      amount: (j['amount'] ?? j['doseAmount'] ?? '1') as String,
      unit: (j['unit'] ?? j['stockUnit'] ?? 'unit') as String,
      instructions: (j['instructions'] ?? '') as String,
      timezone: (j['timezone'] ?? 'UTC') as String,
      minutes: parseMinutes(),
      weekdays: j['weekdays'] == null
          ? const [1, 2, 3, 4, 5, 6, 7]
          : List<int>.from(j['weekdays'] as List),
      startsOn: DateTime.parse((j['startsOn'] ?? j['startDate']) as String),
      endsOn:
          j['endsOn'] == null ? null : DateTime.parse(j['endsOn'] as String),
      paused: j['paused'] as bool? ?? false,
      archived: j['archived'] as bool? ?? false,
      revision: j['revision'] as int? ?? 1,
      effectiveFrom: j['effectiveFrom'] == null
          ? null
          : DateTime.parse(j['effectiveFrom'] as String),
      effectiveUntil: j['effectiveUntil'] == null
          ? null
          : DateTime.parse(j['effectiveUntil'] as String),
      recordingStartedAt: j['recordingStartedAt'] == null
          ? null
          : DateTime.parse(j['recordingStartedAt'] as String),
    );
  }
}

enum DoseAction { taken, skipped, undo, snooze }

class DoseEvent {
  final String id, occurrenceId;
  final DoseAction action;
  final DateTime recordedAt;
  final DateTime? snoozedUntil;
  const DoseEvent({
    required this.id,
    required this.occurrenceId,
    required this.action,
    required this.recordedAt,
    this.snoozedUntil,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'occurrenceId': occurrenceId,
        'action': action.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
      };
  factory DoseEvent.fromJson(Map<String, dynamic> j) => DoseEvent(
        id: (j['id'] ?? j['occurrenceId'] ?? '') as String,
        occurrenceId: (j['occurrenceId'] ?? '') as String,
        action: DoseAction.values.byName(j['action'] as String),
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
      );
}

class DoseOccurrence {
  final Medication medication;
  final DateTime dueAt;
  final String id;
  final DoseEvent? latestEvent;
  final bool remindersAllowed;
  final bool canceled;
  const DoseOccurrence({
    required this.medication,
    required this.dueAt,
    required this.id,
    this.latestEvent,
    this.remindersAllowed = true,
    this.canceled = false,
  });
  bool get isTaken => latestEvent?.action == DoseAction.taken;
  bool get isSkipped => latestEvent?.action == DoseAction.skipped;
  bool get isComplete => isTaken || isSkipped;
  DateTime get alertAt => latestEvent?.action == DoseAction.snooze
      ? latestEvent!.snoozedUntil!
      : dueAt;
  String status(DateTime now) => isTaken
      ? 'Taken'
      : isSkipped
          ? 'Skipped'
          : canceled
              ? 'Canceled'
              : remindersAllowed &&
                      latestEvent?.action == DoseAction.snooze &&
                      alertAt.isAfter(now)
                  ? 'Snoozed'
                  : !dueAt.isAfter(now)
                      ? 'Unconfirmed'
                      : 'Upcoming';

  Map<String, dynamic> toJson() => {
        'medication': medication.toJson(),
        'dueAt': dueAt.toUtc().toIso8601String(),
        'id': id,
      };

  factory DoseOccurrence.fromJson(Map<String, dynamic> j) => DoseOccurrence(
        medication: Medication.fromJson(
          Map<String, dynamic>.from(j['medication'] as Map),
        )..validate(),
        dueAt: DateTime.parse(j['dueAt'] as String),
        id: j['id'] as String,
      );
}

/// Calendar recurrence in the plan's named timezone; end date is inclusive.
/// DST gaps move to the next valid local time; folds produce one occurrence.
class ScheduleEngine {
  const ScheduleEngine();

  /// Resolve gaps to the first valid minute on that calendar day. A repeated
  /// wall time uses the later instant once. Skip a wholly nonexistent date.
  tz.TZDateTime? _wallTime(tz.Location zone, DateTime date, int minute) {
    final naive = DateTime.utc(date.year, date.month, date.day);
    final offsets = [-2, 0, 2]
        .map((days) => tz.TZDateTime.from(naive.add(Duration(days: days)), zone)
            .timeZoneOffset)
        .toSet();
    for (var selected = minute; selected < 1440; selected++) {
      final wall = DateTime.utc(
          date.year, date.month, date.day, selected ~/ 60, selected % 60);
      final matches = offsets
          .map((offset) => tz.TZDateTime.from(wall.subtract(offset), zone))
          .where((candidate) =>
              candidate.year == date.year &&
              candidate.month == date.month &&
              candidate.day == date.day &&
              candidate.hour * 60 + candidate.minute == selected)
          .toList()
        ..sort((a, b) => a.compareTo(b));
      if (matches.isNotEmpty) return matches.last;
    }
    return null;
  }

  List<DoseOccurrence> generate(
    List<Medication> plans,
    List<DoseEvent> events,
    DateTime from,
    DateTime until,
  ) {
    final latest = <String, DoseEvent>{};
    for (final event in events) {
      latest[event.occurrenceId] = event;
    }
    final doses = <DoseOccurrence>[];
    for (final plan in plans) {
      if (plan.paused || plan.archived) continue;
      final zone = tz.getLocation(plan.timezone);
      final localFrom = tz.TZDateTime.from(from, zone);
      final localUntil = tz.TZDateTime.from(until, zone);
      for (var date = calendarDate(localFrom);
          !date.isAfter(calendarDate(localUntil));
          date = DateTime(date.year, date.month, date.day + 1)) {
        if (date.isBefore(calendarDate(plan.startsOn)) ||
            (plan.endsOn != null && date.isAfter(calendarDate(plan.endsOn!))) ||
            !plan.weekdays.contains(date.weekday)) {
          continue;
        }
        for (final minute in plan.minutes) {
          final due = _wallTime(zone, date, minute);
          if (due == null ||
              due.isBefore(from) ||
              !due.isBefore(until) ||
              (plan.effectiveFrom != null &&
                  due.isBefore(plan.effectiveFrom!)) ||
              (plan.effectiveUntil != null &&
                  !due.isBefore(plan.effectiveUntil!))) {
            continue;
          }
          final id = '${plan.id}:${plan.revision}:${dateKey(date)}:$minute';
          doses.add(
            DoseOccurrence(
              medication: plan,
              dueAt: DateTime.fromMillisecondsSinceEpoch(
                due.millisecondsSinceEpoch,
                isUtc: true,
              ),
              id: id,
              latestEvent: latest[id],
            ),
          );
        }
      }
    }
    doses.sort((a, b) {
      final order = a.dueAt.compareTo(b.dueAt);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return doses;
  }
}
