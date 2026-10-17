import 'package:flutter/foundation.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';

class FakeNotifications implements MedicineNotifications {
  @override
  final intent = ValueNotifier<ReminderIntent?>(null);
  final canceled = <String>[];
  int clears = 0;
  bool failScheduling = false;
  bool failInitialization = false;
  bool lastForceRebuild = false;
  String timezone = 'Asia/Kolkata';
  String? lastOwner;
  MedicineData lastData = const MedicineData();
  @override
  Future<void> initialize() async {
    if (failInitialization) {
      throw StateError('Reminder initialization unavailable');
    }
  }

  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  Future<void> cancelDose(String id) async {
    canceled.add(id);
  }

  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<String> deviceTimezone() async => timezone;
  @override
  Future<ReminderReadiness> sync(
    String? owner,
    MedicineData data,
    DateTime now, {
    bool forceRebuild = false,
  }) async {
    if (failScheduling) throw StateError('Scheduler unavailable');
    lastOwner = owner;
    lastForceRebuild = forceRebuild;
    lastData = data;
    return const ReminderReadiness(
      supported: true,
      notifications: true,
      exact: true,
    );
  }
}

Medication testMedication({
  String id = 'med-1',
  String name = 'Test medicine',
  List<int> times = const [480, 1200],
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  DateTime? start,
  DateTime? end,
  String zone = 'Asia/Kolkata',
  String amount = '1',
}) =>
    Medication(
      id: id,
      name: name,
      strength: '500 mg',
      form: 'Tablet',
      amount: amount,
      unit: 'tablet',
      timezone: zone,
      minutes: times,
      weekdays: days,
      startsOn: start ?? DateTime(2026, 10, 1),
      endsOn: end,
    );
