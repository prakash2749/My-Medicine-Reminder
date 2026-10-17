import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_report_view.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_pdf.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/app_preferences.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _OfflineAuth extends AuthService {
  @override
  User? get currentUser => null;
  @override
  Stream<AuthState>? get onAuthStateChange => null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'hi']) {
    testWidgets(
        '$language native guest report, reset and interrupted-reset recovery',
        (tester) async {
      // Run only on the disposable MedicineReminder_QA emulator, with synthetic data.
      final preferences = AppPreferences();
      await preferences.ready;
      await preferences.setLanguage(language);
      await preferences.setGuest(true);
      final notifications = LocalMedicineNotifications();
      var store = EncryptedMedicineStore();
      await notifications.initialize();
      await store.resetAll();
      var provider =
          MedicineReminderProvider(store: store, notifications: notifications);
      provider.bindUser(AppPreferences.guestOwner);
      await provider.ready;
      expect(provider.errorMessage, isNull);
      expect(provider.readiness.notifications, isTrue,
          reason: 'Grant notification permission on the QA emulator.');
      final now = DateTime.now();
      final medication = Medication(
          id: 'epics-demo',
          name: 'दवा Demo medicine',
          strength: '100 mg',
          amount: '0.5',
          unit: 'tablet',
          instructions: 'Synthetic instructions only',
          timezone: await notifications.deviceTimezone(),
          minutes: [(now.hour * 60 + now.minute + 5) % 1440],
          startsOn: calendarDate(now));
      expect(await provider.addMedication(medication), isTrue);
      final original = provider.nextDoses.first;
      expect(
          await provider.startStock(provider.medications.single, '10', '2',
              requestId: 'baseline-$language'),
          isTrue);
      expect(await provider.act(original, DoseAction.snooze), isTrue);
      expect(await provider.act(original, DoseAction.taken), isTrue);
      expect(
          await provider.updateStock(provider.stockFor(medication.id)!,
              quantity: '2', refill: true, requestId: 'refill-$language'),
          isTrue);
      expect(
          provider.stockBalance(provider.stockFor(medication.id)!.id), 115000);
      expect(await provider.act(original, DoseAction.undo), isTrue);
      expect(
          provider.stockBalance(provider.stockFor(medication.id)!.id), 120000);
      expect(await provider.act(original, DoseAction.taken), isTrue);
      final savedEvents = provider.events.length;
      final fingerprint = provider.reportFingerprint;
      final request = MedicineReportRequest(
          data: provider.reportData,
          from: calendarDate(now),
          until: calendarDate(now).add(const Duration(days: 1)),
          generatedAt: now.add(const Duration(hours: 1)),
          language: language);
      final result = await buildMedicinePdf(request);
      expect(result.bytes.length, greaterThan(1000));
      Future<void> mount(Widget child) async {
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AppPreferences>.value(value: preferences),
              ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(authService: _OfflineAuth())),
              ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider()),
              ChangeNotifierProvider<MedicineReminderProvider>.value(
                  value: provider),
            ],
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('hi')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: child)));
        await tester.pumpAndSettle();
      }

      await mount(
          MedicineReportView(request: request, fingerprint: fingerprint));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('report-$language');
      expect(await provider.act(original, DoseAction.undo), isTrue);
      await tester.pumpAndSettle();
      expect(
          find.text(language == 'hi'
              ? 'रिकॉर्ड बदल गए हैं। यह पूर्वावलोकन बंद करके फिर निर्यात करें।'
              : 'The records changed. Close this preview and export again.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      await store.close();
      store = EncryptedMedicineStore();
      provider =
          MedicineReminderProvider(store: store, notifications: notifications);
      provider.bindUser(AppPreferences.guestOwner);
      await provider.ready;
      expect(provider.events.length, savedEvents + 1);
      expect(
          provider.stockBalance(provider.stockFor(medication.id)!.id), 120000);
      await mount(const MedicineView());
      expect(find.text(language == 'hi' ? 'स्थानीय अतिथि' : 'Local guest'),
          findsOneWidget);
      final cache = await getTemporaryDirectory();
      final temporaryReport = File('${cache.path}/medicine-report-test.pdf');
      await temporaryReport.writeAsBytes(result.bytes);
      const secure = FlutterSecureStorage(
          iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device));
      final keyBefore = await secure.read(key: 'medicine.database.key.v1');
      expect(await provider.resetLocalData(), isTrue);
      expect(await temporaryReport.exists(), isFalse);
      expect(provider.events, isEmpty);
      expect(provider.medications, isEmpty);
      expect(
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
          isEmpty);
      expect(
          await secure.read(key: 'medicine.database.key.v1'), isNot(keyBefore));
      expect(await provider.act(original, DoseAction.taken), isFalse);
      final interruptedPlan = Medication(
          id: 'interrupted-reset',
          name: 'Reset fixture',
          amount: '1',
          unit: 'tablet',
          timezone: medication.timezone,
          minutes: medication.minutes,
          startsOn: medication.startsOn);
      expect(await provider.addMedication(interruptedPlan), isTrue);
      expect(
          await provider.startStock(provider.medications.single, '3', '1',
              requestId: 'before-interruption-$language'),
          isTrue);
      expect(
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
          isNotEmpty);
      final interruptedKey = await secure.read(key: 'medicine.database.key.v1');
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      await store.close();
      // Simulate termination after persisting a reset request, before cleanup.
      await secure.write(key: 'medicine.reset.pending.v1', value: 'requested');
      final recovered = EncryptedMedicineStore();
      await recovered.activate(AppPreferences.guestOwner);
      expect((await recovered.load(AppPreferences.guestOwner)).medications,
          isEmpty);
      expect((await recovered.load(AppPreferences.guestOwner)).stockEntries,
          isEmpty);
      expect(
          await FlutterLocalNotificationsPlugin().pendingNotificationRequests(),
          isEmpty);
      expect(await secure.read(key: 'medicine.database.key.v1'),
          isNot(interruptedKey));
      expect(await secure.read(key: 'medicine.reset.pending.v1'), isNull);
      await recovered.close();
      preferences.dispose();
    });
  }
}
