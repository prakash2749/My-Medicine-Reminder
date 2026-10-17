import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('MED-008: MedicineData payload migration and versioning', () {
    test('v1 payload migrates historical actions into immutable dose snapshots',
        () {
      final v1Json = jsonEncode({
        'version': 1,
        'medications': [
          {
            'id': 'med_1',
            'name': 'Metformin',
            'strength': '500 mg',
            'form': 'Tablet',
            'doseAmount': '1',
            'stockUnit': 'tablets',
            'instructions': 'With food',
            'times': ['08:00:00'],
            'weekdays': [1, 2, 3, 4, 5, 6, 7],
            'startDate': '2026-10-01',
            'endDate': '2026-10-31',
            'timezone': 'Asia/Kolkata',
            'paused': false,
            'archived': false,
            'revision': 1,
            'effectiveFrom': '2026-10-01T00:00:00.000Z',
          }
        ],
        'events': [
          {
            'occurrenceId': 'med_1:1:2026-10-15:480',
            'action': 'taken',
            'recordedAt': '2026-10-15T08:05:00.000Z',
          }
        ],
      });

      final decoded = MedicineData.decode(v1Json);
      expect(decoded.medications.length, 1);
      expect(decoded.medications.first.name, 'Metformin');
      expect(decoded.events.length, 1);
      expect(decoded.events.first.action, DoseAction.taken);

      // Verify v1 migration reconstructed the recorded dose snapshot
      expect(decoded.recordedDoses.length, 1);
      final snapshot = decoded.recordedDoses.first;
      expect(snapshot.id, 'med_1:1:2026-10-15:480');
      expect(snapshot.medication.name, 'Metformin');
    });

    test(
        'v2 payload preserves previous revisions and pre-existing recorded doses',
        () {
      final v2Json = jsonEncode({
        'version': 2,
        'medications': [
          {
            'id': 'med_1',
            'name': 'Metformin XR',
            'strength': '1000 mg',
            'form': 'Tablet',
            'doseAmount': '1',
            'stockUnit': 'tablets',
            'instructions': 'With dinner',
            'times': ['20:00:00'],
            'weekdays': [1, 2, 3, 4, 5, 6, 7],
            'startDate': '2026-10-10',
            'endDate': '2026-10-31',
            'timezone': 'Asia/Kolkata',
            'paused': false,
            'archived': false,
            'revision': 2,
            'effectiveFrom': '2026-10-10T00:00:00.000Z',
          }
        ],
        'previousRevisions': [
          {
            'id': 'med_1',
            'name': 'Metformin',
            'strength': '500 mg',
            'form': 'Tablet',
            'doseAmount': '1',
            'stockUnit': 'tablets',
            'instructions': 'With food',
            'times': ['08:00:00'],
            'weekdays': [1, 2, 3, 4, 5, 6, 7],
            'startDate': '2026-10-01',
            'endDate': '2026-10-09',
            'timezone': 'Asia/Kolkata',
            'paused': false,
            'archived': false,
            'revision': 1,
            'effectiveFrom': '2026-10-01T00:00:00.000Z',
            'effectiveUntil': '2026-10-10T00:00:00.000Z',
          }
        ],
        'recordedDoses': [
          {
            'id': 'med_1:1:2026-10-05:480',
            'medication': {
              'id': 'med_1',
              'name': 'Metformin',
              'strength': '500 mg',
              'form': 'Tablet',
              'doseAmount': '1',
              'stockUnit': 'tablets',
              'instructions': 'With food',
              'times': ['08:00:00'],
              'weekdays': [1, 2, 3, 4, 5, 6, 7],
              'startDate': '2026-10-01',
              'endDate': '2026-10-09',
              'timezone': 'Asia/Kolkata',
              'paused': false,
              'archived': false,
              'revision': 1,
              'effectiveFrom': '2026-10-01T00:00:00.000Z',
            },
            'dueAt': '2026-10-05T02:30:00.000Z',
          }
        ],
        'events': [
          {
            'occurrenceId': 'med_1:1:2026-10-05:480',
            'action': 'taken',
            'recordedAt': '2026-10-05T02:35:00.000Z',
          }
        ],
      });

      final decoded = MedicineData.decode(v2Json);
      expect(decoded.medications.first.revision, 2);
      expect(decoded.previousRevisions.length, 1);
      expect(decoded.previousRevisions.first.name, 'Metformin');
      expect(decoded.recordedDoses.length, 1);
      expect(decoded.recordedDoses.first.medication.strength, '500 mg');
    });

    test('v3 payload decodes inventory accounts, entries, and reminder context',
        () {
      final v3Json = jsonEncode({
        'version': 3,
        'medications': [],
        'events': [],
        'previousRevisions': [],
        'recordedDoses': [],
        'stockAccounts': [
          {
            'id': 'stock_1',
            'medicineId': 'med_1',
            'unit': 'tablets',
            'targetThreshold': 100000,
            'active': true,
            'revision': 1,
            'startedAt': '2026-10-01T00:00:00.000Z',
          }
        ],
        'stockEntries': [
          {
            'id': 'entry_1',
            'accountId': 'stock_1',
            'delta': 300000,
            'type': 'baseline',
            'recordedAt': '2026-10-01T00:00:00.000Z',
          }
        ],
        'reminderContext': {
          'lastReconciledAt': '2026-10-18T00:00:00.000Z',
          'timezone': 'Asia/Kolkata',
          'generation': 1,
        },
        'acknowledgedTimezone': 'Asia/Kolkata',
      });

      final decoded = MedicineData.decode(v3Json);
      expect(decoded.stockAccounts.length, 1);
      expect(decoded.stockAccounts.first.threshold, 100000);
      expect(decoded.stockEntries.length, 1);
      expect(decoded.balance('stock_1'), 300000);
      expect(decoded.reminderContext?.timezone, 'Asia/Kolkata');
      expect(decoded.acknowledgedTimezone, 'Asia/Kolkata');
    });

    test(
        'unsupported payload version throws FormatException without data corruption',
        () {
      final invalidVersionJson = jsonEncode({
        'version': 99,
        'medications': [],
        'events': [],
      });

      expect(
        () => MedicineData.decode(invalidVersionJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed JSON input throws FormatException', () {
      expect(
        () => MedicineData.decode('NOT_A_VALID_JSON{['),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MED-008: MemoryMedicineStore and concurrency/account boundaries', () {
    late MemoryMedicineStore store;

    setUp(() {
      store = MemoryMedicineStore();
    });

    test('isolated accounts do not leak records or state', () async {
      await store.activate('user_A');
      await store.change(
          'user_A',
          (data) => data.copyWith(
                medications: [
                  Medication(
                    id: 'med_a',
                    name: 'Aspirin',
                    form: 'Tablet',
                    amount: '1',
                    unit: 'tablets',
                    minutes: const [540],
                    weekdays: const [1, 2, 3],
                    startsOn: DateTime.utc(2026, 10, 1),
                    timezone: 'Asia/Kolkata',
                    effectiveFrom: DateTime.utc(2026, 10, 1),
                  ),
                ],
              ));

      // Switch to User B
      await store.activate('user_B');
      final userBData = await store.load('user_B');
      expect(userBData.medications, isEmpty);

      // User A data remains intact
      await store.activate('user_A');
      final userAData = await store.load('user_A');
      expect(userAData.medications.length, 1);
      expect(userAData.medications.first.name, 'Aspirin');
    });

    test('change rejects mutation if active owner switched concurrently',
        () async {
      await store.activate('user_A');

      // Intervening account switch
      await store.activate('user_B');

      expect(
        () => store.change('user_A', (data) => data),
        throwsA(isA<StateError>()),
      );
    });

    test('change does not persist partial state if transform throws', () async {
      await store.activate('user_A');

      expect(
        () =>
            store.change('user_A', (_) => throw ArgumentError('Invalid input')),
        throwsA(isA<ArgumentError>()),
      );

      final loaded = await store.load('user_A');
      expect(loaded.medications, isEmpty);
    });
  });
}
