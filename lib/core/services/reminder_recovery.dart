import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_context.dart';
import 'medicine_notifications.dart';
import 'medicine_store.dart';

Future<ReminderContext?> readReminderContext(
  MedicineNotifications notifications,
  DateTime now,
) async {
  try {
    final zone = await notifications.deviceTimezone();
    tz.getLocation(zone);
    Map<Object?, Object?>? native;
    if (notifications is LocalMedicineNotifications &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        native = await const MethodChannel('medicine_reminder/settings')
            .invokeMapMethod<Object?, Object?>('getRecoveryContext');
      } on MissingPluginException {
        /* Headless worker has no activity channel. */
      }
    }
    return ReminderContext(
      timezone: zone,
      wallTime: now,
      elapsedMillis: native?['elapsedMillis'] as int?,
      bootCount: native?['bootCount'] as int?,
      generation: native?['generation'] as int?,
    );
  } catch (_) {
    return null;
  }
}

class ReminderReconciliation {
  final ReminderReadiness readiness;
  final MedicineData data;
  const ReminderReconciliation(this.readiness, this.data);
}

Future<ReminderReconciliation> reconcileReminders(
  MedicineStore store,
  MedicineNotifications notifications,
  DateTime now, {
  ReminderContext? context,
  bool forceRebuild = false,
}) async {
  var status = const ReminderReadiness();
  var snapshot = const MedicineData();
  await store.reconcile((owner, data) async {
    status = await notifications.sync(
      owner,
      data,
      now,
      forceRebuild: forceRebuild ||
          context == null ||
          context.needsRebuild(data.reminderContext),
    );
    snapshot = data.copyWith(
      reminderContext: context,
      stockAccounts: data.stockAccounts
          .map(
            (s) => status.refillAlertsSent.contains(s.id)
                ? s.copyWith(alertedEpisode: s.episode)
                : s,
          )
          .toList(),
    );
    return owner == null ? null : snapshot;
  });
  return ReminderReconciliation(status, snapshot);
}
