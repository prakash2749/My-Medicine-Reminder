import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/models/inventory.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';

import '../support/medicine_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late LocalMedicineNotifications service;
  late Map<int, Map<String, dynamic>> pending;
  late List<MethodCall> calls;
  var enabled = true, exact = true, blockedChannel = false;
  var failCancel = false;
  var blockedRefill = false;
  final now = DateTime.utc(2026, 10, 17, 4, 30);
  void testAt(String name, Future<void> Function() body) =>
      test(name, () => withClock(Clock.fixed(now), body));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LocalMedicineNotifications();
    pending = {};
    calls = [];
    enabled = true;
    exact = true;
    blockedChannel = false;
    failCancel = false;
    blockedRefill = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {'notificationLaunchedApp': false};
        case 'areNotificationsEnabled':
          return enabled;
        case 'canScheduleExactNotifications':
          return exact;
        case 'getNotificationChannels':
          return blockedChannel || blockedRefill
              ? [
                  {
                    'id': blockedRefill
                        ? 'medicine_refills_v1'
                        : 'medicine_doses_v1',
                    'name': 'Medicine reminders',
                    'importance': 0,
                    'playSound': true,
                    'enableVibration': true,
                    'enableLights': false,
                    'showBadge': true,
                    'bypassDnd': false,
                    'ledColor': 0,
                    'audioAttributesUsage': 5,
                  },
                ]
              : [];
        case 'getActiveNotifications':
          return [];
        case 'pendingNotificationRequests':
          return pending.values.toList();
        case 'zonedSchedule':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          pending[args['id'] as int] = {
            'id': args['id'],
            'title': args['title'],
            'body': args['body'],
            'payload': args['payload'],
          };
          return null;
        case 'cancel':
          if (failCancel) throw PlatformException(code: 'cancel-failed');
          pending.remove((call.arguments as Map)['id']);
          return null;
        case 'cancelAll':
          pending.clear();
          return null;
        default:
          return null;
      }
    });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testAt(
      'language refresh changes native actions without changing occurrence timing',
      () async {
    final data = MedicineData(medications: [testMedication()]);
    await service.sync('alice', data, now);
    final original = Map<int, Map<String, dynamic>>.from(pending);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app.language', 'hi');
    await service.sync('alice', data, now);
    expect(pending.keys.toSet(), original.keys.toSet());
    for (final entry in pending.entries) {
      expect(entry.value['title'], 'दवा का रिमाइंडर');
      final before =
          jsonDecode(original[entry.key]!['payload'] as String) as Map;
      final after = jsonDecode(entry.value['payload'] as String) as Map;
      expect(after['due'], before['due']);
      expect(after['dose'], before['dose']);
      expect(after['language'], 'hi');
    }
    final schedule = calls.lastWhere((c) => c.method == 'zonedSchedule');
    expect(jsonEncode(schedule.arguments), contains('ले ली'));
    expect(jsonEncode(schedule.arguments), contains('15 मिनट बाद याद दिलाएँ'));
  });
  testAt(
      'native alarms are reconciled idempotently with private content and bounded dates',
      () async {
    final data = MedicineData(
      medications: [testMedication(end: DateTime(2026, 10, 18))],
    );
    final status = await service.sync('alice', data, now);
    expect(status.notifications, isTrue);
    expect(
      pending,
      hasLength(3),
    ); // Today evening plus tomorrow morning/evening.
    final firstCount = calls.where((c) => c.method == 'zonedSchedule').length;
    await service.sync('alice', data, now);
    expect(
      calls.where((c) => c.method == 'zonedSchedule'),
      hasLength(firstCount),
    );
    expect(
      pending.values.every((p) => p['title'] == 'Medicine reminder'),
      isTrue,
    );
    expect(
      pending.values.any(
        (p) => (p['body'] as String).contains('Test medicine'),
      ),
      isFalse,
    );
    final payload =
        jsonDecode(pending.values.first['payload'] as String) as Map;
    expect(payload['owner'], 'alice');
    expect(payload['dose'], startsWith('med-1:'));
  });
  testAt(
    'snooze reschedules one occurrence and completion cancels it',
    () async {
      final medicine = testMedication(end: DateTime(2026, 10, 17));
      final dose = const ScheduleEngine().generate(
        [medicine],
        [],
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      ).firstWhere((d) => d.dueAt.isBefore(now));
      final event = DoseEvent(
        id: 'snooze-1',
        occurrenceId: dose.id,
        action: DoseAction.snooze,
        recordedAt: now,
        snoozedUntil: now.add(const Duration(minutes: 15)),
      );
      await service.sync(
        'alice',
        MedicineData(medications: [medicine], events: [event]),
        now,
      );
      expect(pending, hasLength(2));
      final id = LocalMedicineNotifications.notificationId(dose.id);
      expect(
        jsonDecode(pending[id]!['payload'] as String)['alert'],
        event.snoozedUntil!.toUtc().toIso8601String(),
      );
      final completed = DoseEvent(
        id: 'taken',
        occurrenceId: dose.id,
        action: DoseAction.taken,
        recordedAt: now,
      );
      await service.sync(
        'alice',
        MedicineData(medications: [medicine], events: [event, completed]),
        now,
      );
      expect(pending, hasLength(1));
      expect(pending.containsKey(id), isFalse);
    },
  );
  testAt(
      'permission denial, blocked channel, exact-alarm degradation and logout are explicit',
      () async {
    final data = MedicineData(medications: [testMedication()]);
    exact = false;
    final degraded = await service.sync('alice', data, now);
    expect(degraded.exact, isFalse);
    expect(degraded.message, contains('may arrive late'));
    expect(pending, isNotEmpty);
    enabled = false;
    expect((await service.sync('alice', data, now)).notifications, isFalse);
    expect(pending, isEmpty);
    enabled = true;
    blockedChannel = true;
    expect((await service.sync('alice', data, now)).notifications, isFalse);
    blockedChannel = false;
    await service.sync('alice', data, now);
    expect(pending, isNotEmpty);
    await service.sync(null, const MedicineData(), now);
    expect(pending, isEmpty);
  });
  testAt(
    'edit cancels obsolete alarms before replacements and archive clears them',
    () async {
      final original = testMedication(end: DateTime(2026, 10, 18));
      final morning = const ScheduleEngine()
          .generate([original], [], DateTime.utc(2026, 10, 17), now).single;
      final event = DoseEvent(
        id: 'snooze',
        occurrenceId: morning.id,
        action: DoseAction.snooze,
        recordedAt: now,
        snoozedUntil: now.add(const Duration(minutes: 15)),
      );
      final originalData = MedicineData(
        medications: [original],
        events: [event],
        recordedDoses: [morning],
      );
      await service.sync('alice', originalData, now);
      final oldIds = pending.keys.toSet();
      expect(oldIds, isNotEmpty);
      final next = Medication.fromJson(
        original.toJson()
          ..['minutes'] = [1260]
          ..['revision'] = 2
          ..['effectiveFrom'] = now.toIso8601String(),
      );
      final edited = originalData.copyWith(
        medications: [next],
        previousRevisions: [original.copyWith(effectiveUntil: now)],
      );
      calls.clear();
      await service.sync('alice', edited, now);
      expect(pending.keys.any(oldIds.contains), isFalse);
      final lastCancel = calls.lastIndexWhere((c) => c.method == 'cancel');
      final firstSchedule = calls.indexWhere(
        (c) => c.method == 'zonedSchedule',
      );
      expect(lastCancel, greaterThanOrEqualTo(0));
      expect(firstSchedule, greaterThan(lastCancel));
      expect(
        pending.values.every(
          (p) => (jsonDecode(p['payload'] as String)['dose'] as String)
              .startsWith('med-1:2:'),
        ),
        isTrue,
      );
      await service.sync(
        'alice',
        edited.copyWith(medications: [next.copyWith(archived: true)]),
        now,
      );
      expect(pending, isEmpty);
    },
  );

  testAt(
      'cancellation failure prevents replacement scheduling and retry repairs alarms',
      () async {
    final original = testMedication();
    await service.sync('alice', MedicineData(medications: [original]), now);
    final edited = MedicineData(
      medications: [original.copyWith(revision: 2, effectiveFrom: now)],
    );
    calls.clear();
    failCancel = true;
    await expectLater(
      service.sync('alice', edited, now),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    failCancel = false;
    await service.sync('alice', edited, now);
    expect(pending, isNotEmpty);
    expect(
      pending.values.every(
        (p) => (jsonDecode(p['payload'] as String)['dose'] as String)
            .startsWith('med-1:2:'),
      ),
      isTrue,
    );
  });

  testAt(
    'forced system repair replaces matching cached alarms without past alerts',
    () async {
      final data = MedicineData(medications: [testMedication()]);
      await service.sync('alice', data, now);
      final ids = pending.keys.toSet();
      calls.clear();
      await service.sync('alice', data, now, forceRebuild: true);
      expect(pending.keys.toSet(), ids);
      expect(calls.where((c) => c.method == 'cancel'), hasLength(ids.length));
      expect(
        calls.where((c) => c.method == 'zonedSchedule'),
        hasLength(ids.length),
      );
      expect(
        pending.values.every(
          (p) => DateTime.parse(
            jsonDecode(p['payload'] as String)['alert'] as String,
          ).isAfter(now),
        ),
        isTrue,
      );
    },
  );

  MedicineData lowStockData() => MedicineData(
        medications: [testMedication()],
        stockAccounts: [
          StockAccount(
            id: 'stock',
            medicineId: 'med-1',
            unit: 'tablet',
            threshold: 20000,
            openedAt: now,
          ),
        ],
        stockEntries: [
          StockEntry(
            id: 'initial',
            accountId: 'stock',
            delta: 10000,
            kind: StockEntryKind.initial,
            recordedAt: now,
          ),
        ],
      );

  testAt(
      'refill notices are private, once per acknowledged episode, and reset by refill',
      () async {
    final data = lowStockData();
    final first = await service.sync('alice', data, now);
    expect(first.refillAlertsSent, ['stock']);
    final shown = calls.singleWhere((c) => c.method == 'show').arguments as Map;
    expect(shown['title'], 'Refill reminder');
    expect((shown['body'] as String).contains('Test medicine'), isFalse);
    expect(jsonDecode(shown['payload'] as String)['refill'], 'med-1');
    final acknowledged = data.copyWith(
      stockAccounts: [data.stockAccounts.single.copyWith(alertedEpisode: 1)],
    );
    calls.clear();
    expect(
      (await service.sync('alice', acknowledged, now)).refillAlertsSent,
      isEmpty,
    );
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    final refilled = acknowledged.copyWith(
      stockAccounts: [acknowledged.stockAccounts.single.copyWith(episode: 2)],
    );
    expect((await service.sync('alice', refilled, now)).refillAlertsSent, [
      'stock',
    ]);
    expect(calls.where((c) => c.method == 'show'), hasLength(1));
  });

  testAt(
    'refill permission denial or blocked channel does not acknowledge an alert',
    () async {
      final data = lowStockData();
      enabled = false;
      expect(
        (await service.sync('alice', data, now)).refillAlertsSent,
        isEmpty,
      );
      enabled = true;
      blockedRefill = true;
      final blocked = await service.sync('alice', data, now);
      expect(blocked.refillNotifications, isFalse);
      expect(blocked.refillAlertsSent, isEmpty);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
      blockedRefill = false;
      expect((await service.sync('alice', data, now)).refillAlertsSent, [
        'stock',
      ]);
    },
  );

  testAt(
    'paused or archived stock does not create refill notifications',
    () async {
      for (final med in [
        testMedication().copyWith(paused: true),
        testMedication().copyWith(archived: true),
      ]) {
        final data = lowStockData().copyWith(medications: [med]);
        expect(
          (await service.sync('alice', data, now)).refillAlertsSent,
          isEmpty,
        );
      }
      expect(calls.where((c) => c.method == 'show'), isEmpty);
    },
  );

  testAt('pausing removes pending alarms without deleting the plan', () async {
    final medicine = testMedication();
    await service.sync('alice', MedicineData(medications: [medicine]), now);
    expect(pending, isNotEmpty);
    await service.sync(
      'alice',
      MedicineData(medications: [medicine.copyWith(paused: true)]),
      now,
    );
    expect(pending, isEmpty);
  });
}
