import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_history_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_refills_view.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/core/services/reminder_background.dart';
import 'package:medicine_reminder/core/theme/app_theme.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DeviceAuth extends AuthService {
  @override
  User get currentUser => User(
        id: 'device-test',
        appMetadata: {},
        userMetadata: {'full_name': 'Device test'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'device-test@example.invalid',
      );
  @override
  Stream<AuthState>? get onAuthStateChange => null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'encrypted native storage, alarm reconciliation and dose actions',
    (tester) async {
      await initializeReminderBackground();
      final service = LocalMedicineNotifications();
      var store = EncryptedMedicineStore();
      var provider = MedicineReminderProvider(
        store: store,
        notifications: service,
      );
      // Use only a synthetic account on a disposable emulator.
      provider.bindUser('device-test');
      await provider.ready;
      expect(provider.errorMessage, isNull);
      await store.change('device-test', (_) => const MedicineData());
      await provider.refresh();
      final now = DateTime.now();
      final zone = await service.deviceTimezone();
      final time = ((now.hour * 60 + now.minute) + 5) % 1440;
      final medicine = Medication(
        id: 'native-test-plan',
        name: 'Synthetic medicine',
        amount: '0.5',
        unit: 'tablet',
        strength: '100 mg',
        timezone: zone,
        minutes: [time],
        startsOn: calendarDate(now),
      );
      medicine.validate();
      final saved = await provider.addMedication(medicine);
      expect(saved, isTrue, reason: provider.errorMessage);
      expect(provider.readiness.error, isNull);
      expect(
        provider.readiness.notifications,
        isTrue,
        reason: 'Grant POST_NOTIFICATIONS before running this test.',
      );
      expect(provider.readiness.scheduledThrough, isNotNull);
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isNotEmpty,
      );
      final dose = provider.nextDoses.first;
      expect(
        await provider.startStock(
          provider.medications.single,
          '1',
          '0.5',
          requestId: 'native-stock',
        ),
        isTrue,
      );
      expect(await provider.act(dose, DoseAction.snooze), isTrue);
      expect(await provider.act(dose, DoseAction.taken), isTrue);
      expect(provider.stockBalance(provider.stockFor(medicine.id)!.id), 5000);
      expect(
        provider.stockFor(medicine.id)!.alertedEpisode,
        provider.stockFor(medicine.id)!.episode,
      );
      final refillNotifications =
          await FlutterLocalNotificationsPlugin().getActiveNotifications();
      expect(
        refillNotifications.any((n) => n.title == 'Refill reminder'),
        isTrue,
      );
      expect(provider.events.last.action, DoseAction.taken);
      final originalBalance = provider.stockBalance(
        provider.stockFor(medicine.id)!.id,
      );
      const settings = MethodChannel('medicine_reminder/settings');
      expect(
        await settings.invokeMethod<bool>('enqueueReminderRecovery'),
        isTrue,
      );
      var recovered = false;
      for (var attempt = 0; attempt < 30; attempt++) {
        final states =
            await settings.invokeListMethod<String>('getRecoveryWorkState') ??
                [];
        if (states.contains('SUCCEEDED') &&
            !states.any((s) => s == 'RUNNING' || s == 'ENQUEUED')) {
          recovered = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(
        recovered,
        isTrue,
        reason: 'Native recovery worker did not complete.',
      );
      await provider.refresh();
      expect(
        provider.stockBalance(provider.stockFor(medicine.id)!.id),
        originalBalance,
      );
      expect(provider.events, hasLength(2));
      final originalDoseId = dose.id;
      expect(
        (await FlutterLocalNotificationsPlugin().pendingNotificationRequests())
            .any(
          (notification) =>
              notification.id ==
              LocalMedicineNotifications.notificationId(dose.id),
        ),
        isFalse,
      );
      // Close and reopen the actual SQLCipher database; no in-memory test adapter.
      await store.close();
      provider.dispose();
      store = EncryptedMedicineStore();
      provider = MedicineReminderProvider(store: store, notifications: service);
      provider.bindUser('device-test');
      await provider.ready;
      expect(provider.medications.single.amount, '0.5');
      expect(provider.events.last.action, DoseAction.taken);
      Medication editedPlan(int offset) => Medication(
            id: medicine.id,
            name: 'Edited synthetic medicine',
            amount: '1',
            unit: medicine.unit,
            strength: '200 mg',
            timezone: medicine.timezone,
            minutes: [(time + offset) % 1440],
            startsOn: medicine.startsOn,
            revision: provider.medications.single.revision,
          );
      expect(await provider.editMedication(editedPlan(60)), isTrue);
      expect(
        provider
            .recordedHistory(medicine.id)
            .firstWhere((d) => d.id == originalDoseId)
            .medication
            .amount,
        '0.5',
      );
      final snoozedDose = provider.nextDoses.first;
      expect(await provider.act(snoozedDose, DoseAction.snooze), isTrue);
      final snoozedAlarm = LocalMedicineNotifications.notificationId(
        snoozedDose.id,
      );
      expect(
        (await FlutterLocalNotificationsPlugin().pendingNotificationRequests())
            .any((p) => p.id == snoozedAlarm),
        isTrue,
      );
      expect(await provider.editMedication(editedPlan(120)), isTrue);
      final replacements =
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
      expect(replacements, isNotEmpty);
      expect(replacements.any((p) => p.id == snoozedAlarm), isFalse);
      expect(
        replacements.every(
          (p) => (jsonDecode(p.payload!)['dose'] as String).startsWith(
            '${medicine.id}:3:',
          ),
        ),
        isTrue,
      );
      expect(
        await provider.setPaused(provider.medications.single, true),
        isTrue,
      );
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isEmpty,
      );
      expect(
        await provider.setPaused(provider.medications.single, false),
        isTrue,
      );
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isNotEmpty,
      );
      expect(
        await provider.archiveMedication(provider.medications.single),
        isTrue,
      );
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isEmpty,
      );
      final retainedEvents = provider.events.length;
      await store.close();
      provider.dispose();
      store = EncryptedMedicineStore();
      provider = MedicineReminderProvider(store: store, notifications: service);
      provider.bindUser('device-test');
      await provider.ready;
      expect(provider.medications.single.archived, isTrue);
      expect(provider.events, hasLength(retainedEvents));
      expect(
        provider
            .recordedHistory(medicine.id)
            .any((d) => d.id == originalDoseId && d.isTaken),
        isTrue,
      );
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isEmpty,
      );
      final auth = AuthProvider(authService: _DeviceAuth());
      final historyNow = DateTime.now();
      final historyStart = historyNow.subtract(const Duration(hours: 1));
      final historyLater = historyStart.add(const Duration(minutes: 10));
      final historyMedicine = Medication(
        id: 'native-history-plan',
        name: 'History sample',
        amount: '1',
        unit: 'tablet',
        timezone: await service.deviceTimezone(),
        minutes: [
          historyStart.hour * 60 + historyStart.minute,
          historyLater.hour * 60 + historyLater.minute,
        ],
        startsOn: calendarDate(historyStart),
        endsOn: calendarDate(historyNow),
      );
      await provider.addMedication(historyMedicine);
      final pastRecords = provider
          .dosesBetween(
            historyStart.subtract(const Duration(minutes: 1)),
            historyNow,
          )
          .where((d) => d.medication.id == historyMedicine.id)
          .toList();
      expect(pastRecords.length, greaterThanOrEqualTo(2));
      await provider.act(pastRecords[0], DoseAction.taken);
      await provider.act(pastRecords[1], DoseAction.skipped);
      await provider.setPaused(
        provider.medications.firstWhere((m) => m.id == historyMedicine.id),
        true,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
            ),
            ChangeNotifierProvider<MedicineReminderProvider>.value(
              value: provider,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const MedicineView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await binding.convertFlutterSurfaceToImage();
      await tester.ensureVisible(find.byKey(const Key('open-history')));
      await tester.tap(find.byKey(const Key('open-history')));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineHistoryView), findsOneWidget);
      await binding.takeScreenshot('history-dashboard');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-refills')));
      await tester.tap(find.byKey(const Key('open-refills')));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineRefillsView), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('refill-dashboard');
      await tester.tap(find.text('Edited synthetic medicine'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicineStockView), findsOneWidget);
      await binding.takeScreenshot('stock-ledger');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await provider.deleteMedication(medicine.id), isTrue);
      expect(await provider.deleteMedication(historyMedicine.id), isTrue);
      expect(
        await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
        isEmpty,
      );
      provider.bindUser(null);
      await provider.ready;
      provider.dispose();
      auth.dispose();
    },
  );
}
