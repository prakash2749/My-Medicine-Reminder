import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'medicine_notifications.dart';
import 'medicine_store.dart';
import 'reminder_recovery.dart';

/// Housekeeping only: delivery uses native local alarms, never a periodic job.
@pragma('vm:entry-point')
void reminderCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final store = EncryptedMedicineStore();
    try {
      final notifications = LocalMedicineNotifications();
      await notifications.initialize();
      final now = DateTime.now();
      await reconcileReminders(
        store,
        notifications,
        now,
        context: await readReminderContext(notifications, now),
        forceRebuild: true,
      );
      return true;
    } catch (_) {
      // WorkManager retries; locked/unavailable keys never cause data resets.
      return false;
    } finally {
      await store.close();
    }
  });
}

Future<void> initializeReminderBackground() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(reminderCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'medicine-reminder-reconcile',
    'medicine-reminder-reconcile',
    frequency: const Duration(hours: 12),
    initialDelay: const Duration(hours: 12),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
