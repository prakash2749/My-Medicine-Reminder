import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/core/services/reminder_background.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';

/// First run seeds a synthetic account. Subsequent runs verify OS-triggered
/// headless recovery BEFORE binding a provider (which would repair on startup).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('system recovery fixture preserves confirmations and inventory', (
    tester,
  ) async {
    await initializeReminderBackground();
    final notifications = LocalMedicineNotifications();
    await notifications.initialize();
    final store = EncryptedMedicineStore();
    final data = await store.load('system-fixture');
    if (data.medications.isEmpty) {
      final provider = MedicineReminderProvider(
        store: store,
        notifications: notifications,
      );
      provider.bindUser('system-fixture');
      await provider.ready;
      final now = DateTime.now(), zone = await notifications.deviceTimezone();
      final minute = (now.hour * 60 + now.minute + 90) % 1440;
      Medication plan(String id) => Medication(
            id: id,
            name: 'Synthetic system fixture',
            amount: '0.5',
            unit: 'tablet',
            timezone: zone,
            minutes: [minute],
            startsOn: calendarDate(now),
          );
      await provider.addMedication(plan('system-active'));
      await provider.startStock(
        provider.medications.single,
        '10',
        '2',
        requestId: 'fixture-stock',
      );
      final dose = provider.nextDoses.single;
      await provider.act(dose, DoseAction.taken);
      await provider.act(dose, DoseAction.undo);
      await provider.act(dose, DoseAction.taken);
      await provider.addMedication(plan('system-paused'));
      await provider.setPaused(
        provider.medications.firstWhere((m) => m.id == 'system-paused'),
        true,
      );
      await provider.addMedication(plan('system-archived'));
      await provider.archiveMedication(
        provider.medications.firstWhere((m) => m.id == 'system-archived'),
      );
      expect(
        provider.stockBalance(provider.stockFor('system-active')!.id),
        95000,
      );
      expect(provider.events, hasLength(3));
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isNotEmpty,
      );
      provider.dispose();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('System fixture seeded'))),
      );
    } else {
      const settings = MethodChannel('medicine_reminder/settings');
      var succeeded = false;
      for (var attempt = 0; attempt < 45; attempt++) {
        final states =
            await settings.invokeListMethod<String>('getRecoveryWorkState') ??
                [];
        if (states.contains('SUCCEEDED') &&
            !states.any((s) => s == 'RUNNING' || s == 'ENQUEUED')) {
          succeeded = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(
        succeeded,
        isTrue,
        reason: 'No successful system-event recovery worker.',
      );
      final restored = await store.load('system-fixture');
      expect(restored.events, hasLength(3));
      expect(restored.balance(restored.stockFor('system-active')!.id), 95000);
      expect(
        restored.medications.firstWhere((m) => m.id == 'system-paused').paused,
        isTrue,
      );
      expect(
        restored.medications
            .firstWhere((m) => m.id == 'system-archived')
            .archived,
        isTrue,
      );
      final pending =
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
      expect(pending, isNotEmpty);
      for (final item in pending) {
        final payload = jsonDecode(item.payload!) as Map;
        expect(
          (payload['dose'] as String).startsWith('system-active:'),
          isTrue,
        );
        expect(
          DateTime.parse(payload['alert'] as String).isAfter(DateTime.now()),
          isTrue,
        );
      }
      expect(pending.map((p) => p.id).toSet(), hasLength(pending.length));
      final originals = restored.recordedDoses;
      expect(originals, hasLength(1));
      expect(
        pending.any(
          (p) => jsonDecode(p.payload!)['dose'] == originals.single.id,
        ),
        isFalse,
      );
      await store.close();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('System recovery verified before foreground repair'),
          ),
        ),
      );
    }
    await tester.pumpAndSettle();
  });
}
