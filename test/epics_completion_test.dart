import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/auth/onboarding/local_welcome_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_settings_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_history_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_refills_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/widgets/add_medicine_sheet.dart';
import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:medicine_reminder/core/l10n/hindi_catalog.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_diagnostics.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_pdf.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/app_preferences.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/medicine_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guest and explicit locale survive a fresh preference object', () async {
    final first = AppPreferences();
    await first.ready;
    expect(await first.setGuest(true), isTrue);
    expect(await first.setLanguage('hi'), isTrue);
    final restarted = AppPreferences();
    await restarted.ready;
    expect(restarted.guestEnabled, isTrue);
    expect(restarted.locale, const Locale('hi'));
    expect(await restarted.setLanguage('unsupported'), isFalse);
    expect(restarted.language, 'hi');
    first.dispose();
    restarted.dispose();
  });

  test('Hindi numeric input normalizes without changing prescription text', () {
    expect(normalizeDigits('०.५'), '0.5');
    expect(normalizeDigits('१२३४५६७८९०'), '1234567890');
    expect(translateCopy('मेरा निर्देश १२', 'hi'), 'मेरा निर्देश १२');
    expect(translateCopy('Taken', 'hi'), 'ले ली');
    expect(translateCopy('2 of 5 doses recorded as taken', 'hi'),
        '5 खुराकों में से 2 को लिया हुआ दर्ज किया गया');
    for (final entry in hindiCatalog.entries) {
      final source =
          RegExp(r'\{\d+\}').allMatches(entry.key).map((m) => m[0]).toSet();
      final translated =
          RegExp(r'\{\d+\}').allMatches(entry.value).map((m) => m[0]).toSet();
      expect(translated, source, reason: entry.key);
    }
  });

  test('diagnostics never expose raw errors, dates, health data or IDs', () {
    final payload = jsonEncode(reminderDiagnostics(ReminderReadiness(
      supported: true,
      error: 'patient@example.invalid SECRET MEDICINE',
      refillAlertsSent: const ['sensitive-owner'],
      scheduledThrough: DateTime(2026, 10, 18, 8),
    )));
    for (final forbidden in [
      'patient',
      'SECRET',
      'sensitive-owner',
      '2026',
      '08:00'
    ]) {
      expect(payload, isNot(contains(forbidden)));
    }
    expect(payload, contains('not measured'));
    expect(payload, contains('"remoteTelemetry":false'));
  });

  test('guest records remain separate from an authenticated profile', () async {
    final store = MemoryMedicineStore();
    final provider = MedicineReminderProvider(
        store: store, notifications: FakeNotifications());
    provider.bindUser(AppPreferences.guestOwner);
    await provider.ready;
    expect(await provider.addMedication(testMedication()), isTrue);
    provider.bindUser('signed-in');
    await provider.ready;
    expect(provider.medications, isEmpty);
    provider.bindUser(AppPreferences.guestOwner);
    await provider.ready;
    expect(provider.medications.single.name, 'Test medicine');
    provider.dispose();
  });

  test('reset clears every profile and stale intents cannot recreate records',
      () async {
    final store = MemoryMedicineStore();
    final notifications = FakeNotifications();
    final provider =
        MedicineReminderProvider(store: store, notifications: notifications);
    provider.bindUser('other');
    await provider.ready;
    await provider.addMedication(testMedication(id: 'other'));
    provider.bindUser(AppPreferences.guestOwner);
    await provider.ready;
    await provider.addMedication(testMedication());
    final dose = provider.nextDoses.first;
    final fingerprint = provider.reportFingerprint;
    expect(await provider.resetLocalData(), isTrue);
    expect(
        store.records.values.every((data) => data.medications.isEmpty), isTrue);
    expect(provider.reportFingerprint, isNot(fingerprint));
    expect(await provider.act(dose, DoseAction.taken), isFalse);
    expect(provider.events, isEmpty);
    expect(await provider.resetLocalData(), isTrue);
    provider.dispose();
  });

  test('failed reset reports failure and retry succeeds', () async {
    final store = MemoryMedicineStore();
    final provider = MedicineReminderProvider(
        store: store, notifications: FakeNotifications());
    provider.bindUser('guest');
    await provider.ready;
    await provider.addMedication(testMedication());
    store.failWrites = true;
    expect(await provider.resetLocalData(), isFalse);
    expect(provider.errorMessage, contains('Reset could not finish'));
    expect(store.records['guest']!.medications, hasLength(1));
    store.failWrites = false;
    expect(await provider.resetLocalData(), isTrue);
    expect(provider.medications, isEmpty);
    provider.dispose();
  });

  test('report uses filtered original quantities, zones and unresolved status',
      () async {
    final provider = MedicineReminderProvider(
        store: MemoryMedicineStore(),
        notifications: FakeNotifications(),
        clock: () => DateTime.utc(2026, 10, 18, 15));
    provider.bindUser('report');
    await provider.ready;
    await provider.addMedication(
        testMedication(id: 'included', name: 'दवा का नाम १२', amount: '0.5'));
    await provider
        .addMedication(testMedication(id: 'excluded', name: 'DO NOT INCLUDE'));
    final request = MedicineReportRequest(
        data: provider.reportData,
        from: DateTime(2026, 10, 18),
        until: DateTime(2026, 10, 19),
        generatedAt: DateTime.utc(2026, 10, 18, 20),
        medicineId: 'included');
    final text = request.paragraphs().join('\n');
    expect(text, contains('दवा का नाम १२'));
    expect(text, contains('0.5 tablet'));
    expect(text, contains('Asia/Kolkata'));
    expect(text, isNot(contains('DO NOT INCLUDE')));
    expect(text, contains('Unconfirmed'));
    provider.dispose();
  });

  testWidgets('multilingual report renders paginated synthetic PDF offline',
      (tester) async {
    await tester.runAsync(() async {
      await (FontLoader('ReportHindi')
            ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf')))
          .load();
      final medicine = testMedication(
              name:
                  'लंबा दवा नाम - Synthetic long medicine name for legibility verification',
              amount: '0.5')
          .copyWith(recordingStartedAt: DateTime.utc(2026, 10, 1));
      final withInstructions = Medication.fromJson({
        ...medicine.toJson(),
        'instructions': List.generate(80, (i) => 'Line $i').join('\n')
      });
      final data = MedicineData(medications: [withInstructions]);
      final result = await buildMedicinePdf(
          MedicineReportRequest(
              data: data,
              from: DateTime(2026, 10, 1),
              until: DateTime(2026, 10, 8),
              generatedAt: DateTime.utc(2026, 10, 10),
              language: 'hi'),
          keepPageImages: true);
      expect(ascii.decode(result.bytes.take(4).toList()), '%PDF');
      expect(result.pageImages.length, greaterThan(1));
      final directory = Directory('build/epics-report');
      await directory.create(recursive: true);
      await File('${directory.path}/synthetic-report.pdf')
          .writeAsBytes(result.bytes);
      for (var i = 0; i < result.pageImages.length; i++) {
        await File('${directory.path}/page-${i + 1}.png')
            .writeAsBytes(result.pageImages[i]);
      }
    });
  });

  for (final language in ['en', 'hi']) {
    testWidgets('$language core screens fit narrow screen at 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = AppPreferences();
      await preferences.ready;
      final provider = MedicineReminderProvider(
          store: MemoryMedicineStore(), notifications: FakeNotifications());
      provider.bindUser('accessibility');
      await provider.ready;
      await provider.addMedication(testMedication());
      for (final screen in [
        const LocalWelcomeView(),
        const MedicineSettingsView(),
        const MedicineHistoryView(),
        const MedicineRefillsView(),
        const AddMedicineSheet()
      ]) {
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AppPreferences>.value(value: preferences),
              ChangeNotifierProvider<MedicineReminderProvider>.value(
                  value: provider),
            ],
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('hi')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: Scaffold(body: screen)))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$language ${screen.runtimeType}');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      preferences.dispose();
    });
  }
}
