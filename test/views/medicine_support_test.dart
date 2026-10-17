import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_settings_view.dart';
import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:medicine_reminder/core/services/medicine_diagnostics.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/app_preferences.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/medicine_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> clipboardWrites;
  late bool failClipboard;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clipboardWrites = [];
    failClipboard = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failClipboard) {
          throw PlatformException(
              code: 'unavailable', message: 'PRIVATE PLATFORM DETAILS');
        }
        clipboardWrites.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('support bundle is strictly allowlisted and excludes sensitive inputs',
      () {
    final bundle = reminderDiagnosticBundle(ReminderReadiness(
      supported: true,
      notifications: true,
      exact: false,
      refillNotifications: false,
      scheduledThrough: DateTime.utc(2026, 10, 18, 9, 12),
      error: 'SECRET MEDICINE patient@example.invalid /private/database.db',
      refillAlertsSent: const ['PRIVATE OWNER:DOSE-ID'],
    ));
    expect(jsonDecode(bundle), {
      'schema': 1,
      'scope': 'local-readiness',
      'remoteTelemetry': false,
      'schedulingSupported': true,
      'notificationPermission': true,
      'preciseAlarmPermission': false,
      'refillChannelEnabled': false,
      'futureSchedulePresent': true,
      'reconciliationFailed': true,
      'callbackObserved': 'not measured',
      'posted': 'not measured',
      'humanReceipt': 'not measured',
    });
    for (final forbidden in [
      'SECRET',
      'patient',
      'database.db',
      'PRIVATE',
      '2026',
      '09:12'
    ]) {
      expect(bundle, isNot(contains(forbidden)));
    }
    expect(jsonDecode(reminderDiagnosticBundle(const ReminderReadiness())),
        containsPair('futureSchedulePresent', false));
  });

  Future<MedicineReminderProvider> showSettings(WidgetTester tester,
      {String language = 'en', double scale = 1}) async {
    final preferences = AppPreferences();
    await preferences.ready;
    final provider = MedicineReminderProvider(
        store: MemoryMedicineStore(), notifications: FakeNotifications());
    provider.bindUser('PRIVATE ACCOUNT');
    await provider.ready;
    await provider.addMedication(testMedication(name: 'PRIVATE MEDICINE'));
    addTearDown(preferences.dispose);
    addTearDown(provider.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPreferences>.value(value: preferences),
        ChangeNotifierProvider<MedicineReminderProvider>.value(value: provider),
      ],
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('hi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const MedicineSettingsView(),
      ),
    ));
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> openReview(WidgetTester tester) async {
    final button = find.byKey(const Key('review-diagnostics'));
    await tester.scrollUntilVisible(button, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('review, cancel and back never write to the clipboard',
      (tester) async {
    await showSettings(tester);
    await openReview(tester);
    expect(find.byKey(const Key('diagnostic-preview')), findsOneWidget);
    expect(clipboardWrites, isEmpty);
    await tester.tap(find.byKey(const Key('cancel-diagnostics')));
    await tester.pumpAndSettle();
    expect(clipboardWrites, isEmpty);
    await openReview(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(clipboardWrites, isEmpty);
    expect(find.byKey(const Key('diagnostic-preview')), findsNothing);
    await openReview(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(clipboardWrites, isEmpty);
    expect(find.byKey(const Key('diagnostic-preview')), findsNothing);
  });

  testWidgets('copies the reviewed snapshot even after readiness changes',
      (tester) async {
    final provider = await showSettings(tester);
    await openReview(tester);
    final preview = tester
        .widget<SelectableText>(find.byKey(const Key('diagnostic-preview')))
        .data!;
    final notifications = provider.notifications as FakeNotifications;
    notifications.failScheduling = true;
    await provider.refresh();
    await tester.pumpAndSettle();
    expect(reminderDiagnosticBundle(provider.readiness), isNot(preview));
    expect(clipboardWrites, isEmpty);
    await tester.tap(find.byKey(const Key('copy-diagnostics')));
    await tester.pumpAndSettle();
    expect(clipboardWrites, [preview]);
    expect(preview, isNot(contains('PRIVATE')));
    expect(find.text('Diagnostics copied. Choose where to paste them.'),
        findsOneWidget);
    await openReview(tester);
    final refreshed = tester
        .widget<SelectableText>(find.byKey(const Key('diagnostic-preview')))
        .data!;
    expect(refreshed, reminderDiagnosticBundle(provider.readiness));
    expect(jsonDecode(refreshed), containsPair('reconciliationFailed', true));
    expect(clipboardWrites, hasLength(1));
  });

  testWidgets(
      'clipboard failure reports failure without raw details; retry works',
      (tester) async {
    await showSettings(tester);
    failClipboard = true;
    await openReview(tester);
    await tester.tap(find.byKey(const Key('copy-diagnostics')));
    await tester.pumpAndSettle();
    expect(clipboardWrites, isEmpty);
    expect(
        find.text('Could not copy diagnostics. Please retry.'), findsOneWidget);
    expect(find.textContaining('PRIVATE PLATFORM'), findsNothing);
    expect(find.text('Diagnostics copied. Choose where to paste them.'),
        findsNothing);
    // Let the first result leave the snackbar queue before retrying.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    failClipboard = false;
    await openReview(tester);
    await tester.tap(find.byKey(const Key('copy-diagnostics')));
    await tester.pumpAndSettle();
    expect(clipboardWrites, hasLength(1));
    expect(find.text('Diagnostics copied. Choose where to paste them.'),
        findsOneWidget);
  });

  for (final language in ['en', 'hi']) {
    testWidgets('$language review/copy fits narrow screen at 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showSettings(tester, language: language, scale: 2);
      await openReview(tester);
      expect(find.text(translateCopy('Review diagnostics', language)),
          findsWidgets);
      final preview = find.byKey(const Key('diagnostic-preview'));
      await tester.scrollUntilVisible(preview, 250,
          scrollable: find
              .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Scrollable))
              .first);
      expect(tester.widget<SelectableText>(preview).textDirection,
          TextDirection.ltr);
      final copy = find.byKey(const Key('copy-diagnostics'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(clipboardWrites, hasLength(1));
      expect(
          find.text(translateCopy(
              'Diagnostics copied. Choose where to paste them.', language)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
